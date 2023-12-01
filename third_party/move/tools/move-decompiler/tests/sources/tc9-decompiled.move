module 0x12::tc9 {
    public fun foo() : u64 {
        let v0 = 0;
        loop {
            let v1 = v0 + 1;
            v0 = v1;
            if (v1 / 2 == 0) {
                continue
            };
            if (v1 == 5) {
                break
            };
            v0 = v1 + 69 + v1;
        };
        v0 + 99
    }
    
    // decompiled from Move bytecode v6
}
