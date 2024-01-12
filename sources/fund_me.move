module 0x8ea41b701444a79634ca4df3c414474f5241af3e94466139bfc9204d972caed1::fund_me {
    
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use 0x1::signer; 
    use 0x1::event;
    use 0x1::timestamp;
    use 0x1::storage;

    /* use when close fund is attempted and neither expiry or target value have been hit */
    const EFUND_NOT_EXPIRED: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;
    const EFUND_EXPIRED: u64 = 3;

    struct Fund<CoinType> has store {
        current_value: Coin<CoinType>,
        target_value: u64,
        expires: u64,
    }

    #[event]
    struct FundClose {
        timestamp: u64,
        final_value: u64,
        target_reached: bool,
    }

    #[event]
    struct TransferEvent has drop {
        sender: address,
        amount: u64,
    }

    public entry fun initialize(account: &signer, contract_duration_seconds: u64, target_value: u64){
        // Add checks for validity of contract_duration_seconds and target_value if needed
        let deadline:u64 = timestamp::now_seconds() + contract_duration_seconds;
        let initial_value = Coin::zero<AptosCoin>();

        let new_contract = Fund<AptosCoin> {
            current_value: initial_value,
            target_value:target_value,
            expires: deadline,
        };

        //publish the Fund under the address
        storage::move_to(account, new_contract);        
    }

    public entry fun add_value(account: &signer, amount_to_add: u64) {

        let signer_address = signer::address_of(account);
        let signer_balance = aptos_framework::coin::balance<AptosCoin>(signer_address);
        assert!(signer_balance >= amount_to_add, EINSUFFICIENT_BALANCE, "Insufficient balance to add value to the fund.");

        //gets mutable reference to the Fund stored under the address
        let fund = borrow_global_mut<Fund<AptosCoin>>(signer_address);
        if (timestamp::now_seconds() > fund.deadline) {
            close_fund(account);
            abort EFUND_EXPIRED;
        }
        let coins_to_add = aptos_framework::coin::withdraw_from_sender<AptosCoin>(account, amount_to_add);
        aptos_framework::coin::deposit(&mut fund.current_value, coins_to_add);

        event::emit(TransferEvent {
            sender: signer_address,
            amount: coins_to_add,
        });

        if (fund.current_value >= fund.target_value) {
            close_fund(account);   
        }

    }

    public entry fun check_value(address: address): u64 acquires Fund {
        if (exists<Fund<AptosCoin>>(address)) {
            let fund_reference = borrow_global<Fund<AptosCoin>>(address);
            return fund_reference.current_value.value;
        }
        return 0;        
    }

    fun close_fund(account: &signer) acquires Fund {
        let signer_address = signer::address_of(account);
        let fund = borrow_global_mut<Fund<AptosCoin>>(signer_address);
        let current_time = timestamp::now_seconds();
        
        let final_value = fund.current_value.value;
        let target_reached = false;
        if (final_value >= fund.target_value) {
            target_reached = true;
        } 

        if (fund.expires > current_time && !target_reached) {
            abort EFUND_NOT_EXPIRED;
        }

        
        event::emit(FundClose {
            timestamp: current_time,
            final_value: final_value,
            target_reached: target_reached, 
        });

        aptos_framework::coin::deposit(account, move(fund.current_value));

        move_from<Fund<AptosCoin>>(signer_address);
    } 

}
