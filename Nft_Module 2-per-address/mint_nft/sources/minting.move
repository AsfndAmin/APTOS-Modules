//TO DEPLOY aptos move create-resource-account-and-publish-package --seed 123 --address-name mint_nft --profile accountaddress
//TO MINT aptos move run --function-id 66a578cfc4c71f99dab29937a95e5d330e095b7a74938b4ad68384a317ba1159::minting::mint_nft --args u64:9 --profile testnet1
//CHANGE RECOURCE ACCOUNT OTHER VALUES IN ABOVE COMMAND ACCORDING TO REQUIRENTS


module mint_nft::minting {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    //use std::option::{Self, Option};
    use aptos_std::table::{Self, Table};
    use std::vector;

    use aptos_framework::aptos_account;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
 //   use aptos_std::ed25519;
    use aptos_token::token::{Self, TokenDataId };//, TokenDataId, Token  
    use aptos_framework::resource_account;



    // This struct stores the token receiver's address and token_data_id in the event of token minting
    struct TokenMintingEvent has drop, store {
        token_receiver_address: address,
        token_data_id: TokenDataId,
        counter: u64,
    }

    // This struct stores an NFT collection's relevant information
    struct ModuleData has key {
       // public_key: ed25519::ValidatedPublicKey,
        signer_cap: account::SignerCapability,
        expiration_timestamp: u64,
        minting_enabled: bool,
        token_minting_events: EventHandle<TokenMintingEvent>,
        mint_fee: u64,
        fee_receiver_address: address,
        admin_account_address: address,
        maximum_supply: u64,
        collection_name: String,
        description: String,
        collection_uri: String,
        token_name: String,
        token_base_uri: String,
        supply_counter: u64,
        creator_address: address,
         

    }


    struct TotalMinted has key {
        minted_per_address: Table<address ,u64>

    }

    // //This struct stores the number of nfts a account minted
    // struct TotalMintedByAddress has copy, drop, store {
    //     minter: address,
    //     amount: u8,

    // }


    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// The collection minting is expired
    const ECOLLECTION_EXPIRED: u64 = 2;
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 3;
    /// Specified public key is not the same as the admin's public key
    const EWRONG_PUBLIC_KEY: u64 = 4;
    /// Specified scheme required to proceed with the smart contract operation - can only be ED25519_SCHEME(0) OR MULTI_ED25519_SCHEME(1)
    const EINVALID_SCHEME: u64 = 5;
    /// Specified proof of knowledge required to prove ownership of a public key is invalid
    const EINVALID_PROOF_OF_KNOWLEDGE: u64 = 6;
    /// Max Supply reached
    const MAX_SUPPLY_REACHED: u64 = 7;
    //user can mint max 2 nfts per transaction
    const EMAX_TWO_PER_TX: u64 = 8;
    //check if total minted per address is initialized
    const ENOT_INITIALIZED: u64 = 9;
    //only two nfts per address allowed
    const EMAX_TWO_PER_ADDR: u64 = 10;

    

    // /// Initialize this module: create a resource account, a collection, and a token data id
    // fun init_module(resource_account: &signer) {
    //     // NOTE: This is just an example PK; please replace this with your desired admin PK.
    //     let hardcoded_pk = x"83f5e31d9d6c42ee2f03b3861cd55fc0088b8901ad729ea9bf952d0af32d90cc";
    //     init_module_with_admin_public_key(resource_account, hardcoded_pk);
    // }

    fun init_module(resource_account: &signer) {
        let collection_name = string::utf8(b"BMD NFT");
        let description = string::utf8(b"Description");
        let collection_uri = string::utf8(b"www.collection.com");
        let token_name = string::utf8(b"Aptos#");
        let token_base_uri = string::utf8(b"www.bmd.com/");
        let expiration_timestamp = 1671599635;
        //add mint fee here in octas
        let mint_fee = 1000;
        // add fee receiver address here
        let fee_receiver_address = @fee_receiver_addr;
        //admin account
        let admin_account_address = @admin_addr;
        //supply counter
        let supply_counter = 0;
       
        // change source_addr to the actual account that created the resource account
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_account, @source_addr);
        let resource_signer = account::create_signer_with_capability(&resource_signer_cap);

        // create the nft collection
        let maximum_supply = 6666;
        let mutate_setting = vector<bool>[ false, false, false ];
        // creator address
        let creator_address = signer::address_of(resource_account);
        
        //creating data to store amount of tokens per address
                let totalminted = TotalMinted {
            minted_per_address: table::new(),
        };
        move_to(resource_account, totalminted);


       // let resource_account_address = signer::address_of(&resource_signer);
        token::create_collection(&resource_signer, collection_name, description, collection_uri, maximum_supply, mutate_setting);


       // let public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));

        move_to(resource_account, ModuleData {
          //  public_key,
            signer_cap: resource_signer_cap,
            expiration_timestamp,
            minting_enabled: true,
            token_minting_events: account::new_event_handle<TokenMintingEvent>(&resource_signer),
            mint_fee,
            fee_receiver_address,
            admin_account_address,
            maximum_supply,
            collection_name,
            description,
            collection_uri,
            token_name,
            token_base_uri,
            supply_counter,
            creator_address,

        });
    }

    /// Set if minting is enabled for this minting contract
    public entry fun set_minting_enabled(caller: &signer, minting_enabled: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.minting_enabled = minting_enabled;
    }

    /// Set the expiration timestamp of this minting contract
    public entry fun set_timestamp(caller: &signer, expiration_timestamp: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.expiration_timestamp = expiration_timestamp;
    }

    // /// Set the public key of this minting contract
    // public entry fun set_public_key(caller: &signer, pk_bytes: vector<u8>) acquires ModuleData {
    //     let caller_address = signer::address_of(caller);
    //     assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
    //     let module_data = borrow_global_mut<ModuleData>(@mint_nft);
    //     module_data.public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));
    // }

        /// Set the fee receiver address of this minting contract
    public entry fun set_fee_collector(caller: &signer, fee_collector: address) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.fee_receiver_address = fee_collector;
    }

            /// Set the mintfee of this minting contract
    public entry fun change_set_fee(caller: &signer, fee: u64) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        module_data.mint_fee = fee;
    }


    // Mint an NFT to the receiver.
    //Take MInt Fee from receiver
    public entry fun mint_nft(receiver: &signer, amount: u64) acquires ModuleData, TotalMinted{
        let receiver_addr = signer::address_of(receiver);

        // get the collection minter and check if the collection minting is disabled or expired
        let module_data = borrow_global_mut<ModuleData>(@mint_nft);
        assert!(timestamp::now_seconds() < module_data.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
        assert!(module_data.minting_enabled, error::permission_denied(EMINTING_DISABLED));
        assert!(amount <= 2, error::permission_denied(EMAX_TWO_PER_TX));

        //get signer
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

        //store minted amount data per address
        //assert!(exists<TotalMinted>(resource_signer), error::not_found(ENOT_INITIALIZED));
        //let minted_per_address = &mut borrow_global_mut<TotalMinted>(resource_signer).minted_per_address;
        //let minted_per_address =borrow_global_mut<TotalMinted>(@mint_nft).minted_per_address;

        let minted_per_addr = &mut borrow_global_mut<TotalMinted>(@mint_nft).minted_per_address;
        let present = table::contains(minted_per_addr, receiver_addr);
        if(present == false){
        //if false add data
        table::add(minted_per_addr, receiver_addr, amount);
        }else{
        //if true then check, then stop or update data
        let ref = table::borrow_mut(minted_per_addr, receiver_addr);
        let x = 1;
        let r = &mut x;
        if(ref == r){
            assert!(amount == 1, error::permission_denied(EMAX_TWO_PER_ADDR));
            table::upsert(minted_per_addr, receiver_addr,(amount + 1))
        }else{
            //assert!(error::permission_denied(EMAX_TWO_PER_ADDR));
             abort 42
        }
        };
        //Take mint fee from nft minter
          //Take mint fee from nft minter
        let total_fee = (amount* module_data.mint_fee);
        aptos_account::transfer(receiver, module_data.fee_receiver_address, total_fee);


    
        // mint token to the receiver
      

        let i = 0;
        loop {
        i = i + 1;
        if (i > amount) break;

        //generate name and uri
        let newName = module_data.token_name;
        let uri = module_data.token_base_uri;
        let count = num_str(module_data.supply_counter);
        string::insert(&mut uri, 12 , count);
        string::insert(&mut newName, 6 , count);

        let token_data_id = token::create_tokendata(
            &resource_signer,
            module_data.collection_name,
            newName,
            string::utf8(b""),
            1,
            uri,
            receiver_addr,
            1,
            0,
            // we don't allow any mutation to the token
            token::create_token_mutability_config(
                &vector<bool>[ false, false, false, false, false ]
            ),
            vector::empty<String>(),
            vector::empty<vector<u8>>(),
            vector::empty<String>(),
        );
        let token_id = token::mint_token(&resource_signer, token_data_id, 1);
        token::direct_transfer(&resource_signer, receiver, token_id, 1);
        let counter = module_data.supply_counter;
        event::emit_event<TokenMintingEvent>(
            &mut module_data.token_minting_events,
            TokenMintingEvent {
                token_receiver_address: receiver_addr,
                token_data_id: token_data_id,
                counter,
            }
        );

    module_data.supply_counter = module_data.supply_counter + 1;
   
 };

    }

    fun num_str(num: u64): String{

    let v1 = vector::empty();

    while (num/10 > 0){
        let rem = num%10;
       // vector::push_back(&mut v1, rem+48);
        vector::push_back(&mut v1, (rem+48 as u8));
        num = num/10;
    };

    //vector::push_back(&mut v1, num+48);
    vector::push_back(&mut v1, (num+48 as u8));

    vector::reverse(&mut v1);

    string::utf8(v1)
}



        /// Burn a token by the token owner
    public entry fun burnOwnToken(
        owner: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        
    ) {

        token::burn(owner, creators_address, collection, name, property_version, 1) 
    }


        // Transfers token from `from` to `to`.
    public entry fun transferToken(
        from: &signer,
        creator: address,
        collection: String,
        name: String,
        to: address,
    ) {
      let tokenid =  token::create_token_id_raw(creator, collection, name, 0);
       token::transfer(from, tokenid, to, 1);

    }


    public entry fun transferTokenCheck(
        from: &signer,
        name: String,
        to: address,
    ) acquires ModuleData{
         let module_data = borrow_global_mut<ModuleData>(@mint_nft);
      let tokenid =  token::create_token_id_raw(module_data.creator_address, module_data.collection_name, name, 0);
       token::transfer(from, tokenid, to, 1);

    }


    //user need to be opt in to recieve token through direct transfer
    public entry fun enable_opt_in_direct_transfer(account: &signer, opt_in: bool) {
       token::opt_in_direct_transfer(account, opt_in) ;
    }




}