module 0x1::aggregator_v2 {
    struct AggregatorSnapshot<T0> has drop, store {
        value: T0,
    }
    
    native public fun copy_snapshot<T0: copy + drop>(arg0: &AggregatorSnapshot<T0>) : AggregatorSnapshot<T0>;
    native public fun create_snapshot<T0: copy + drop>(arg0: T0) : AggregatorSnapshot<T0>;
    native public fun read_snapshot<T0>(arg0: &AggregatorSnapshot<T0>) : T0;
    native public fun string_concat<T0>(arg0: 0x1::string::String, arg1: &AggregatorSnapshot<T0>, arg2: 0x1::string::String) : AggregatorSnapshot<0x1::string::String>;
    // decompiled from Move bytecode v6
}
