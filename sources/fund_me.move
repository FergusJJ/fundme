module 0x8ea41b701444a79634ca4df3c414474f5241af3e94466139bfc9204d972caed1::fund_me {

    use 0x1::coin::{Self, Coin};
    use 0x1::aptos_coin::AptosCoin;
    use 0x1::signer;
    use 0x1::event;
    use 0x1::timestamp;
    use 0x1::vector;

    /* use when close fund is attempted and neither expiry or target value have been hit */
    const EFUND_NOT_EXPIRED: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;
    const EFUND_TIME_EXPIRED: u64 = 3;
    const EFUND_NOT_FOUND: u64 = 4;
    const EFUND_TARGET_REACHED: u64 = 5;
    const EFUND_ALREADY_EXISTS: u64 = 6;

    struct Fund<phantom CoinType> has key, store {
        deposits: vector<Coin<CoinType>>,
        target_value: u64,
        expires: u64,
        target_reached: bool,
    }

    #[event]
    struct FundClose has drop, store {
        timestamp: u64,
        final_value: u64,
        target_reached: bool,
        target_value: u64,
    }

    #[event]
    struct TransferEvent has drop, store {
        sender: address,
        amount: u64,
    }


    #[view]
    public fun check_value(address: address): u64 acquires Fund {
        assert!(exists<Fund<AptosCoin>>(address), EFUND_NOT_FOUND); // "There is no fund under this address."
        let fund_reference = borrow_global<Fund<AptosCoin>>(address);
        assert!(fund_reference.expires > timestamp::now_seconds(), EFUND_TIME_EXPIRED); // "The fund has expired."

        // Using vector::fold to sum up the values of the coins
        sum_coin_vals(&fund_reference.deposits)
    }


    #[view]
    public fun check_deadline(address: address): u64 acquires Fund {
        assert!(exists<Fund<AptosCoin>>(address), EFUND_NOT_FOUND); //"There is no fund under this address."
        let fund_reference = borrow_global<Fund<AptosCoin>>(address);
        assert!(fund_reference.expires > timestamp::now_seconds(), EFUND_TIME_EXPIRED); //"The fund has expired."
        fund_reference.expires
    }

    public entry fun initialize(account: &signer, contract_duration_seconds: u64, target_value: u64){
        // Add checks for validity of contract_duration_seconds and target_value if needed

        let signer_address = signer::address_of(account);
        assert!(!exists<Fund<AptosCoin>>(signer_address), EFUND_ALREADY_EXISTS); //"There is already a fund under this address."

        let deadline:u64 = timestamp::now_seconds() + contract_duration_seconds;

        let new_contract = Fund<AptosCoin> {
            deposits: vector<Coin<AptosCoin>>[],
            target_value:target_value,
            expires: deadline,
            target_reached: false,
        };

        //publish the Fund under the address
        move_to(account, new_contract);
    }

    public entry fun add_value(account: &signer, fund_address: address, amount_to_add: u64) acquires Fund {

        let signer_address = signer::address_of(account);
        let signer_balance = aptos_framework::coin::balance<AptosCoin>(signer_address);

        assert!(signer_balance >= amount_to_add, EINSUFFICIENT_BALANCE); //"Insufficient balance to add value to the fund."

        let fund = borrow_global_mut<Fund<AptosCoin>>(fund_address);

        assert!(!fund.target_reached, EFUND_TARGET_REACHED); //"The target has already been reached for the fund."
        assert!(fund.expires > timestamp::now_seconds(), EFUND_TIME_EXPIRED); //"The fund has expired."

        let coins_to_add = coin::withdraw<AptosCoin>(account, amount_to_add);

        vector::push_back(&mut fund.deposits, coins_to_add);

        event::emit(TransferEvent {
            sender: signer_address,
            amount: amount_to_add,
        });

        let deposit_sum = sum_coin_vals(&fund.deposits);
        if (deposit_sum >= fund.target_value) {
            fund.target_reached = true;
        }
    }



    public entry fun claim_fund(account: &signer) acquires Fund{
        let signer_address = signer::address_of(account);

        assert!(exists<Fund<AptosCoin>>(signer_address), EFUND_NOT_FOUND); //"There is no fund under this address."

        let Fund {deposits, target_reached, expires, target_value} = borrow_global_mut<Fund<AptosCoin>>(signer_address);
        let current_time = timestamp::now_seconds();

        assert!(*target_reached || current_time > *expires, EFUND_NOT_EXPIRED); //"The fund has not reached it's target or expired."

        let is_target_reached = *target_reached;
        let amount = 0;

        // Iterate through the deposits and deposit them to the signer's address
        while (!vector::is_empty(deposits)) {
            let coin = vector::pop_back(deposits);
            amount = amount + coin::value(&coin);
            coin::deposit<AptosCoin>(signer_address, coin);
        };


        event::emit(FundClose {
            timestamp: current_time,
            final_value: amount,
            target_reached: is_target_reached,
            target_value: *target_value,
        });    
    }

    fun sum_coin_vals(coins: &vector<Coin<AptosCoin>>): u64 {
       let sum = 0;

       let len = vector::length(coins);
       for (i in 0..len) {
           let current_deposit = vector::borrow(coins, i);
           sum = sum + coin::value(current_deposit);
       };
       sum
    }

}
