module 0x8ea41b701444a79634ca4df3c414474f5241af3e94466139bfc9204d972caed1::escrow {

    struct Contract has key {
        
        source: address;
        dest: address;
        value: u64;
        exipres: u64;

    }

    public fun check_expiration(contract: &Contract) {

    }

}