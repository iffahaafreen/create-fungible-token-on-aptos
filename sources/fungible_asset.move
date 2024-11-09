module aptos_asset::fungible_asset {
    // Importing the necessary modules
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    // Importing functionalities for fungible assets, including self-reference, minting, transferring, burning, metadata, and fungible asset utilities.

    use aptos_framework::object::{Self, Object};
    // Importing object management functionalities, including self-reference and object handling.

    use aptos_framework::primary_fungible_store;
    // Importing the primary fungible store module.

    use std::error;
    // Importing standard error handling functionalities.

    use std::signer;
    // Importing functionalities for handling signers.

    use std::string::utf8;
    // Importing functionalities for UTF-8 string manipulation.

    use std::option;
    // Importing functionalities for handling optional values.

    /// Only fungible asset metadata owner can make changes.
    // Constants
    const ENOT_OWNER: u64 = 1;
    // Error code indicating that the action is not allowed because the user is not the owner of the fungible asset metadata.

    const ASSET_SYMBOL: vector<u8> = b"META";
    // Symbol for the fungible asset, represented as a vector of bytes.

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef, // Reference for minting assets
        transfer_ref: TransferRef, // Reference for transferring assets
        burn_ref: BurnRef, // Reference for burning assets
    }

    fun init_module(admin: &signer) {
    // Create a named object for the asset using the admin signer and the asset symbol
    let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);

    // Create the primary store for the fungible asset with the specified metadata
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        constructor_ref,
        option::none(), // No specific options
        utf8(b"META Coin"), // Name of the asset
        utf8(ASSET_SYMBOL), // Symbol of the asset
        8, // Number of decimals
        utf8(b"https://drive.google.com/file/d/1vFm-kF6O3onxPgFJ_rVLh9YGFT_fFWM6/view?usp=sharing"), // Icon URL
        utf8(b"http://metaschool.so"), // Project URL
    );

    // Create mint, burn, and transfer references to allow the creator to manage the fungible asset
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

    // Generate a signer for the metadata object
    let metadata_object_signer = object::generate_signer(constructor_ref);

    // Move the managed fungible asset to the metadata object signer's account
    move_to(
        &metadata_object_signer,
        ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
    ); // Initialize the managed fungible asset
}

public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@aptos_asset, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    public entry fun mint(admin: &signer, to: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let managed_fungible_asset = authorized_borrow_refs(admin, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);
    }// <:!:mint

    /// Transfer as the owner of metadata object ignoring `frozen` field.
    public entry fun transfer(admin: &signer, from: address, to: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        fungible_asset::transfer_with_ref(transfer_ref, from_wallet, to_wallet, amount);
    }

    /// Burn fungible assets as the owner of metadata object.
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(admin, asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }


}

