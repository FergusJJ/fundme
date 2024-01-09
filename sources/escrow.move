module 0x8ea41b701444a79634ca4df3c414474f5241af3e94466139bfc9204d972caed1::fund_me {

    use std::signer;
    use aptos_std::timestamp;
    use apts_std::coin::{self, Coin};

    struct Fund<phantom CoinType> has key {

        source: address;
        current_value: u64;
        target_value: u64;
        exipres: u64;

    }

    public entry fun set_contract<CoinType>(account: signer, contract_duration_seconds: u64, target_value: u64){
        let deadline = timestamp::now() + contract_duration_seconds;
        let source_addr = signer::address_of(&account);
        let new_contract:Fund<CoinType> = Fund<CoinType> {
            source: source_addr,
            current_value: 0,
            target_value: target_value,
            expires: deadline,
        }
    }

    public fun contribute(account: signer, amount: u64) acquires Fund {
        let fund = borrow_global_mut<Fund<CoinType>>(signer::address_of(&account));
        next_amount = fund.current_value + amount;
        //don't want to exceed target value, so only send remaining
        if (next_amount >= fund.target_value) {
            amount = amount - (next_amount - fund.target_value);
            coin::deposit(&account, Coin<CoinType>{value: amount});
        } else {
            coin::deposit(&account, Coin<CoinType>{value: amount});

        }
    }

}
