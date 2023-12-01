module 0x1::fungible_asset {
    struct BurnRef has drop, store {
        metadata: 0x1::object::Object<Metadata>,
    }
    
    struct DepositEvent has drop, store {
        amount: u64,
    }
    
    struct FrozenEvent has drop, store {
        frozen: bool,
    }
    
    struct FungibleAsset {
        metadata: 0x1::object::Object<Metadata>,
        amount: u64,
    }
    
    struct FungibleAssetEvents has key {
        deposit_events: 0x1::event::EventHandle<DepositEvent>,
        withdraw_events: 0x1::event::EventHandle<WithdrawEvent>,
        frozen_events: 0x1::event::EventHandle<FrozenEvent>,
    }
    
    struct FungibleStore has key {
        metadata: 0x1::object::Object<Metadata>,
        balance: u64,
        frozen: bool,
    }
    
    struct Metadata has key {
        name: 0x1::string::String,
        symbol: 0x1::string::String,
        decimals: u8,
        icon_uri: 0x1::string::String,
        project_uri: 0x1::string::String,
    }
    
    struct MintRef has drop, store {
        metadata: 0x1::object::Object<Metadata>,
    }
    
    struct Supply has key {
        current: u128,
        maximum: 0x1::option::Option<u128>,
    }
    
    struct TransferRef has drop, store {
        metadata: 0x1::object::Object<Metadata>,
    }
    
    struct WithdrawEvent has drop, store {
        amount: u64,
    }
    
    public fun add_fungibility(arg0: &0x1::object::ConstructorRef, arg1: 0x1::option::Option<u128>, arg2: 0x1::string::String, arg3: 0x1::string::String, arg4: u8, arg5: 0x1::string::String, arg6: 0x1::string::String) : 0x1::object::Object<Metadata> {
        assert!(!0x1::object::can_generate_delete_ref(arg0), 0x1::error::invalid_argument(18));
        let v0 = 0x1::object::generate_signer(arg0);
        let v1 = &v0;
        assert!(0x1::string::length(&arg2) <= 32, 0x1::error::out_of_range(15));
        assert!(0x1::string::length(&arg3) <= 10, 0x1::error::out_of_range(16));
        assert!(arg4 <= 32, 0x1::error::out_of_range(17));
        assert!(0x1::string::length(&arg5) <= 512, 0x1::error::out_of_range(19));
        assert!(0x1::string::length(&arg6) <= 512, 0x1::error::out_of_range(19));
        let v2 = Metadata{
            name        : arg2, 
            symbol      : arg3, 
            decimals    : arg4, 
            icon_uri    : arg5, 
            project_uri : arg6,
        };
        move_to<Metadata>(v1, v2);
        let v3 = Supply{
            current : 0, 
            maximum : arg1,
        };
        move_to<Supply>(v1, v3);
        0x1::object::object_from_constructor_ref<Metadata>(arg0)
    }
    
    public fun amount(arg0: &FungibleAsset) : u64 {
        arg0.amount
    }
    
    public fun asset_metadata(arg0: &FungibleAsset) : 0x1::object::Object<Metadata> {
        arg0.metadata
    }
    
    public fun balance<T0: key>(arg0: 0x1::object::Object<T0>) : u64 acquires FungibleStore {
        if (store_exists(0x1::object::object_address<T0>(&arg0))) {
            borrow_global<FungibleStore>(0x1::object::object_address<T0>(&arg0)).balance
        } else {
            0
        }
    }
    
    public fun burn(arg0: &BurnRef, arg1: FungibleAsset) acquires Supply {
        let FungibleAsset {
            metadata : v0,
            amount   : v1,
        } = arg1;
        let v2 = v0;
        assert!(arg0.metadata == v2, 0x1::error::invalid_argument(13));
        decrease_supply<Metadata>(&v2, v1);
    }
    
    public fun burn_from<T0: key>(arg0: &BurnRef, arg1: 0x1::object::Object<T0>, arg2: u64) acquires FungibleAssetEvents, FungibleStore, Supply {
        let v0 = store_metadata<T0>(arg1);
        assert!(arg0.metadata == v0, 0x1::error::invalid_argument(10));
        let v1 = withdraw_internal(0x1::object::object_address<T0>(&arg1), arg2);
        burn(arg0, v1);
    }
    
    public fun burn_ref_metadata(arg0: &BurnRef) : 0x1::object::Object<Metadata> {
        arg0.metadata
    }
    
    public fun create_store<T0: key>(arg0: &0x1::object::ConstructorRef, arg1: 0x1::object::Object<T0>) : 0x1::object::Object<FungibleStore> {
        let v0 = 0x1::object::generate_signer(arg0);
        let v1 = &v0;
        let v2 = FungibleStore{
            metadata : 0x1::object::convert<T0, Metadata>(arg1), 
            balance  : 0, 
            frozen   : false,
        };
        move_to<FungibleStore>(v1, v2);
        let v3 = 0x1::object::new_event_handle<DepositEvent>(v1);
        let v4 = 0x1::object::new_event_handle<WithdrawEvent>(v1);
        let v5 = 0x1::object::new_event_handle<FrozenEvent>(v1);
        let v6 = FungibleAssetEvents{
            deposit_events  : v3, 
            withdraw_events : v4, 
            frozen_events   : v5,
        };
        move_to<FungibleAssetEvents>(v1, v6);
        0x1::object::object_from_constructor_ref<FungibleStore>(arg0)
    }
    
    public fun decimals<T0: key>(arg0: 0x1::object::Object<T0>) : u8 acquires Metadata {
        borrow_global<Metadata>(0x1::object::object_address<T0>(&arg0)).decimals
    }
    
    fun decrease_supply<T0: key>(arg0: &0x1::object::Object<T0>, arg1: u64) acquires Supply {
        assert!(arg1 != 0, 0x1::error::invalid_argument(1));
        let v0 = 0x1::object::object_address<T0>(arg0);
        assert!(exists<Supply>(v0), 0x1::error::not_found(21));
        let v1 = borrow_global_mut<Supply>(v0);
        assert!(v1.current >= (arg1 as u128), 0x1::error::invalid_state(20));
        v1.current = v1.current - (arg1 as u128);
    }
    
    public fun deposit<T0: key>(arg0: 0x1::object::Object<T0>, arg1: FungibleAsset) acquires FungibleAssetEvents, FungibleStore {
        let v0 = is_frozen<T0>(arg0);
        assert!(!v0, 0x1::error::invalid_argument(3));
        deposit_internal<T0>(arg0, arg1);
    }
    
    fun deposit_internal<T0: key>(arg0: 0x1::object::Object<T0>, arg1: FungibleAsset) acquires FungibleAssetEvents, FungibleStore {
        let FungibleAsset {
            metadata : v0,
            amount   : v1,
        } = arg1;
        if (v1 == 0) {
            return
        };
        let v2 = store_metadata<T0>(arg0);
        assert!(v0 == v2, 0x1::error::invalid_argument(11));
        let v3 = 0x1::object::object_address<T0>(&arg0);
        let v4 = borrow_global_mut<FungibleStore>(v3);
        v4.balance = v4.balance + v1;
        let v5 = &mut borrow_global_mut<FungibleAssetEvents>(v3).deposit_events;
        let v6 = DepositEvent{amount: v1};
        0x1::event::emit_event<DepositEvent>(v5, v6);
    }
    
    public fun deposit_with_ref<T0: key>(arg0: &TransferRef, arg1: 0x1::object::Object<T0>, arg2: FungibleAsset) acquires FungibleAssetEvents, FungibleStore {
        assert!(arg0.metadata == arg2.metadata, 0x1::error::invalid_argument(2));
        deposit_internal<T0>(arg1, arg2);
    }
    
    public fun destroy_zero(arg0: FungibleAsset) {
        let FungibleAsset {
            metadata : _,
            amount   : v1,
        } = arg0;
        assert!(v1 == 0, 0x1::error::invalid_argument(12));
    }
    
    public fun extract(arg0: &mut FungibleAsset, arg1: u64) : FungibleAsset {
        assert!(arg0.amount >= arg1, 0x1::error::invalid_argument(4));
        arg0.amount = arg0.amount - arg1;
        FungibleAsset{
            metadata : arg0.metadata, 
            amount   : arg1,
        }
    }
    
    public fun generate_burn_ref(arg0: &0x1::object::ConstructorRef) : BurnRef {
        BurnRef{metadata: 0x1::object::object_from_constructor_ref<Metadata>(arg0)}
    }
    
    public fun generate_mint_ref(arg0: &0x1::object::ConstructorRef) : MintRef {
        MintRef{metadata: 0x1::object::object_from_constructor_ref<Metadata>(arg0)}
    }
    
    public fun generate_transfer_ref(arg0: &0x1::object::ConstructorRef) : TransferRef {
        TransferRef{metadata: 0x1::object::object_from_constructor_ref<Metadata>(arg0)}
    }
    
    fun increase_supply<T0: key>(arg0: &0x1::object::Object<T0>, arg1: u64) acquires Supply {
        assert!(arg1 != 0, 0x1::error::invalid_argument(1));
        let v0 = 0x1::object::object_address<T0>(arg0);
        assert!(exists<Supply>(v0), 0x1::error::not_found(21));
        let v1 = borrow_global_mut<Supply>(v0);
        if (0x1::option::is_some<u128>(&v1.maximum)) {
            let v2 = *0x1::option::borrow_mut<u128>(&mut v1.maximum) - v1.current >= (arg1 as u128);
            assert!(v2, 0x1::error::out_of_range(5));
        };
        v1.current = v1.current + (arg1 as u128);
    }
    
    public fun is_frozen<T0: key>(arg0: 0x1::object::Object<T0>) : bool acquires FungibleStore {
        let v0 = store_exists(0x1::object::object_address<T0>(&arg0));
        v0 && borrow_global<FungibleStore>(0x1::object::object_address<T0>(&arg0)).frozen
    }
    
    public fun maximum<T0: key>(arg0: 0x1::object::Object<T0>) : 0x1::option::Option<u128> acquires Supply {
        let v0 = 0x1::object::object_address<T0>(&arg0);
        if (exists<Supply>(v0)) {
            borrow_global<Supply>(v0).maximum
        } else {
            0x1::option::none<u128>()
        }
    }
    
    public fun merge(arg0: &mut FungibleAsset, arg1: FungibleAsset) {
        let FungibleAsset {
            metadata : v0,
            amount   : v1,
        } = arg1;
        assert!(v0 == arg0.metadata, 0x1::error::invalid_argument(6));
        arg0.amount = arg0.amount + v1;
    }
    
    public fun metadata_from_asset(arg0: &FungibleAsset) : 0x1::object::Object<Metadata> {
        arg0.metadata
    }
    
    public fun mint(arg0: &MintRef, arg1: u64) : FungibleAsset acquires Supply {
        assert!(arg1 > 0, 0x1::error::invalid_argument(1));
        let v0 = arg0.metadata;
        increase_supply<Metadata>(&v0, arg1);
        FungibleAsset{
            metadata : v0, 
            amount   : arg1,
        }
    }
    
    public fun mint_ref_metadata(arg0: &MintRef) : 0x1::object::Object<Metadata> {
        arg0.metadata
    }
    
    public fun mint_to<T0: key>(arg0: &MintRef, arg1: 0x1::object::Object<T0>, arg2: u64) acquires FungibleAssetEvents, FungibleStore, Supply {
        let v0 = mint(arg0, arg2);
        deposit<T0>(arg1, v0);
    }
    
    public fun name<T0: key>(arg0: 0x1::object::Object<T0>) : 0x1::string::String acquires Metadata {
        borrow_global<Metadata>(0x1::object::object_address<T0>(&arg0)).name
    }
    
    public fun remove_store(arg0: &0x1::object::DeleteRef) acquires FungibleAssetEvents, FungibleStore {
        let v0 = 0x1::object::object_from_delete_ref<FungibleStore>(arg0);
        let v1 = 0x1::object::object_address<FungibleStore>(&v0);
        let FungibleStore {
            metadata : _,
            balance  : v3,
            frozen   : _,
        } = move_from<FungibleStore>(v1);
        assert!(v3 == 0, 0x1::error::permission_denied(14));
        let FungibleAssetEvents {
            deposit_events  : v5,
            withdraw_events : v6,
            frozen_events   : v7,
        } = move_from<FungibleAssetEvents>(v1);
        0x1::event::destroy_handle<DepositEvent>(v5);
        0x1::event::destroy_handle<WithdrawEvent>(v6);
        0x1::event::destroy_handle<FrozenEvent>(v7);
    }
    
    public fun set_frozen_flag<T0: key>(arg0: &TransferRef, arg1: 0x1::object::Object<T0>, arg2: bool) acquires FungibleAssetEvents, FungibleStore {
        let v0 = store_metadata<T0>(arg1);
        assert!(arg0.metadata == v0, 0x1::error::invalid_argument(9));
        let v1 = 0x1::object::object_address<T0>(&arg1);
        borrow_global_mut<FungibleStore>(v1).frozen = arg2;
        let v2 = &mut borrow_global_mut<FungibleAssetEvents>(v1).frozen_events;
        let v3 = FrozenEvent{frozen: arg2};
        0x1::event::emit_event<FrozenEvent>(v2, v3);
    }
    
    public fun store_exists(arg0: address) : bool {
        exists<FungibleStore>(arg0)
    }
    
    public fun store_metadata<T0: key>(arg0: 0x1::object::Object<T0>) : 0x1::object::Object<Metadata> acquires FungibleStore {
        borrow_global<FungibleStore>(0x1::object::object_address<T0>(&arg0)).metadata
    }
    
    public fun supply<T0: key>(arg0: 0x1::object::Object<T0>) : 0x1::option::Option<u128> acquires Supply {
        let v0 = 0x1::object::object_address<T0>(&arg0);
        if (exists<Supply>(v0)) {
            0x1::option::some<u128>(borrow_global<Supply>(v0).current)
        } else {
            0x1::option::none<u128>()
        }
    }
    
    public fun symbol<T0: key>(arg0: 0x1::object::Object<T0>) : 0x1::string::String acquires Metadata {
        borrow_global<Metadata>(0x1::object::object_address<T0>(&arg0)).symbol
    }
    
    public entry fun transfer<T0: key>(arg0: &signer, arg1: 0x1::object::Object<T0>, arg2: 0x1::object::Object<T0>, arg3: u64) acquires FungibleAssetEvents, FungibleStore {
        let v0 = withdraw<T0>(arg0, arg1, arg3);
        deposit<T0>(arg2, v0);
    }
    
    public fun transfer_ref_metadata(arg0: &TransferRef) : 0x1::object::Object<Metadata> {
        arg0.metadata
    }
    
    public fun transfer_with_ref<T0: key>(arg0: &TransferRef, arg1: 0x1::object::Object<T0>, arg2: 0x1::object::Object<T0>, arg3: u64) acquires FungibleAssetEvents, FungibleStore {
        let v0 = withdraw_with_ref<T0>(arg0, arg1, arg3);
        deposit_with_ref<T0>(arg0, arg2, v0);
    }
    
    public fun withdraw<T0: key>(arg0: &signer, arg1: 0x1::object::Object<T0>, arg2: u64) : FungibleAsset acquires FungibleAssetEvents, FungibleStore {
        let v0 = 0x1::object::owns<T0>(arg1, 0x1::signer::address_of(arg0));
        assert!(v0, 0x1::error::permission_denied(8));
        let v1 = is_frozen<T0>(arg1);
        assert!(!v1, 0x1::error::invalid_argument(3));
        withdraw_internal(0x1::object::object_address<T0>(&arg1), arg2)
    }
    
    fun withdraw_internal(arg0: address, arg1: u64) : FungibleAsset acquires FungibleAssetEvents, FungibleStore {
        assert!(arg1 != 0, 0x1::error::invalid_argument(1));
        let v0 = borrow_global_mut<FungibleStore>(arg0);
        assert!(v0.balance >= arg1, 0x1::error::invalid_argument(4));
        v0.balance = v0.balance - arg1;
        let v1 = &mut borrow_global_mut<FungibleAssetEvents>(arg0).withdraw_events;
        let v2 = WithdrawEvent{amount: arg1};
        0x1::event::emit_event<WithdrawEvent>(v1, v2);
        FungibleAsset{
            metadata : v0.metadata, 
            amount   : arg1,
        }
    }
    
    public fun withdraw_with_ref<T0: key>(arg0: &TransferRef, arg1: 0x1::object::Object<T0>, arg2: u64) : FungibleAsset acquires FungibleAssetEvents, FungibleStore {
        let v0 = store_metadata<T0>(arg1);
        assert!(arg0.metadata == v0, 0x1::error::invalid_argument(9));
        withdraw_internal(0x1::object::object_address<T0>(&arg1), arg2)
    }
    
    public fun zero<T0: key>(arg0: 0x1::object::Object<T0>) : FungibleAsset {
        FungibleAsset{
            metadata : 0x1::object::convert<T0, Metadata>(arg0), 
            amount   : 0,
        }
    }
    
    // decompiled from Move bytecode v6
}
