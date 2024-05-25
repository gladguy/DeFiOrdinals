module 0x61a8037e8b94fbaca82959c56a2c31d421056c5ca9c0307b4b07700ade75c05c::MyOrdinalsLoan {
    use std::vector;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::signer;

    resource struct AptosOrdinalNFT {
        id: u64,
        owner: address,
        name: string::String,
        uri: string::String,
        inscription_number: string::String,
        inscription_id: string::String,
        content: string::String,
        content_type: string::String,
        location_blockheight: u64,
    }

    resource struct BurnedNFT {
        nfts: vector<AptosOrdinalNFT>,
    }

    struct MintEvent has copy, drop, store {
        id: u64,
        owner: address,
    }

    struct BurnEvent has copy, drop, store {
        id: u64,
        owner: address,
    }

    resource struct NFTCollection has key {
        nfts: vector<AptosOrdinalNFT>,
        total_supply: u64,
        mint_event: event::EventHandle<MintEvent>,
        burn_event: event::EventHandle<BurnEvent>,
        deployer: address,
    }

    public fun initialize(account: &signer) {
        let collection = NFTCollection {
            nfts: vector::empty<AptosOrdinalNFT>(),
            total_supply: 0,
            mint_event: account::new_event_handle<MintEvent>(account),
            burn_event: account::new_event_handle<BurnEvent>(account),
            deployer: signer::address_of(account),
        };
        move_to(account, collection);
        move_to(account, BurnedNFT { nfts: vector::empty<AptosOrdinalNFT>() });
    }

    public fun mint_nft(
        account: &signer,
        name: string::String,
        uri: string::String,
        inscription_number: string::String,
        inscription_id: string::String,
        content: string::String,
        content_type: string::String
    ) {
        let collection = borrow_global<NFTCollection>(signer::address_of(account));
        assert!(signer::address_of(account) == collection.deployer, 100, "Only the deployer can mint NFTs");

        let collection_mut = borrow_global_mut<NFTCollection>(signer::address_of(account));
        let id = collection_mut.total_supply;
        let location_blockheight: u64 = 844773000;
        let nft = AptosOrdinalNFT {
            id,
            owner: signer::address_of(account),
            name,
            uri,
            inscription_number,
            inscription_id,
            content,
            content_type,
            location_blockheight,
        };
        vector::push_back(&mut collection_mut.nfts, nft);
        event::emit_event(&mut collection_mut.mint_event, MintEvent { id, owner: signer::address_of(account) });
        collection_mut.total_supply = id + 1;
    }

    public fun burn_nft(account: &signer, id: u64) {
        let collection = borrow_global_mut<NFTCollection>(signer::address_of(account));
        let index = find_nft_index(&collection.nfts, id);
        let nft = vector::remove(&mut collection.nfts, index);
        assert!(nft.owner == signer::address_of(account), 101, "Only the owner can burn the NFT");

        let burned_nfts = borrow_global_mut<BurnedNFT>(signer::address_of(account));
        vector::push_back(&mut burned_nfts.nfts, nft);
        
        event::emit_event(&mut collection.burn_event, BurnEvent { id, owner: signer::address_of(account) });
    }

    public fun transfer_nft(account: &signer, to: address, id: u64) {
        let collection = borrow_global_mut<NFTCollection>(signer::address_of(account));
        let index = find_nft_index(&collection.nfts, id);
        let nft = &mut vector::borrow_mut(&mut collection.nfts, index);
        assert!(nft.owner == signer::address_of(account), 102, "Only the owner can transfer the NFT");
        nft.owner = to;
    }

    public fun nft_exists_by_inscription(account: address, inscription_number: string::String, inscription_id: string::String): bool {
        let collection = borrow_global<NFTCollection>(account);
        return exists_in_collection(&collection.nfts, inscription_number, inscription_id);
    }

    public fun burned_nft_exists_by_inscription(account: address, inscription_number: string::String, inscription_id: string::String): bool {
        let burned_nfts = borrow_global<BurnedNFT>(account);
        return exists_in_collection(&burned_nfts.nfts, inscription_number, inscription_id);
    }

    fun exists_in_collection(nfts: &vector<AptosOrdinalNFT>, inscription_number: string::String, inscription_id: string::String): bool {
        let length = vector::length(nfts);
        let mut i = 0;
        while (i < length) {
            let nft = vector::borrow(nfts, i);
            if (nft.inscription_number == inscription_number || nft.inscription_id == inscription_id) {
                return true;
            }
            i = i + 1;
        }
        return false;
    }

    fun find_nft_index(nfts: &vector<AptosOrdinalNFT>, id: u64): u64 {
        let length = vector::length(nfts);
        let mut i = 0;
        while (i < length) {
            let nft = vector::borrow(nfts, i);
            if (nft.id == id) {
                return i;
            }
            i = i + 1;
        }
        abort 404; // NFT not found
    }
}
