-- WoWLegendsPlayer/Data/WarbandProps.lua
-- The Warband Camp prop catalogue: category -> { key, label } pairs.
-- key = what `.camp place <key>` expects · label = what the player sees.
--
-- HARDCODED on purpose: the server has no query API for the catalogue. Props
-- are the v1.5.0 SHIPPED list, verbatim from
-- handoffs/2026-08-09_addon_warband_tab.md (verified against
-- wowlegends_warbandcamp.cpp) — 69 of them, unchanged in v1.6.0. When the
-- catalogue changes in a future repack, that handoff gets a revision — update
-- BOTH the entries and the version note below. `bones`/`bell`/`lodge`/`tower`
-- do NOT exist server-side — never add them.
--
-- CAMP STAFF (repack v1.6.0) are the last category. They ride the SAME
-- `.camp place <key>` command, which is why they live here, but the server
-- keeps them in their own table with their own cap (6, CAMP_MAX_NPCS) — so
-- they do NOT move the prop gauge, and nothing in the reply stream reports how
-- many you already have. Keys/labels are verbatim from g_npcCatalogue.

local addonName, WLP = ...

WLP.WarbandProps = {
    catalogueVersion = "repack v1.7.0",
    staffCap = 6,               -- CAMP_MAX_NPCS; cannot be read back from the server
    categories = {
        { name = "Shelter", props = {
            { "tent", "Tent" }, { "tent-a", "Alliance Tent" }, { "tent-h", "Horde Tent" },
            { "foodtent", "Food Tent" },
        } },
        { name = "Fire & Light", props = {
            { "campfire", "Campfire" }, { "bonfire", "Bonfire" }, { "brazier", "Brazier" },
            { "lantern", "Lantern" },
        } },
        { name = "Furniture", props = {
            { "table", "Table" }, { "chair", "Chair" }, { "bench", "Bench" }, { "rug", "Rug" },
            { "bookshelf", "Bookshelf" }, { "bookcase", "Bookcase" },
        } },
        { name = "Storage", props = {
            { "crate", "Supply Crate" }, { "crate-h", "Horde Crate" }, { "barrel", "Barrel" },
            { "keg", "Keg" }, { "cauldron", "Cauldron" }, { "cookpot", "Cook Pot" },
        } },
        { name = "Yard", props = {
            { "wagon", "Wagon" }, { "haystack", "Haystack" }, { "haybale", "Hay Bale" },
            { "woodpile", "Wood Pile" }, { "logpile", "Log Pile" }, { "fence", "Fence" },
            { "rockwall", "Rockwall Fence" }, { "pumpkin", "Pumpkin" },
        } },
        { name = "Craft", props = {
            { "anvil", "Anvil" }, { "forge", "Forge" }, { "coals", "Forge Coals" },
            { "weaponrack", "Weapon Rack" },
        } },
        { name = "Banners", props = {
            { "banner", "Banner" }, { "banner-a", "Alliance Banner" }, { "banner-h", "Horde Banner" },
        } },
        { name = "Lights", props = {
            { "torch", "Torch" }, { "candle", "Candle" }, { "candelabra", "Candelabra" },
        } },
        { name = "Food & Provisions", props = {
            { "sack", "Grain Sack" }, { "basket", "Basket" }, { "corn", "Basket of Corn" },
            { "bucket", "Bucket" }, { "bottle", "Bottle" }, { "bread", "Bread" },
            { "food", "Spread of Food" }, { "chest", "Chest" },
        } },
        { name = "Atmosphere", props = {
            { "skull", "Skull" }, { "totem", "Totem" }, { "gong", "Gong" }, { "drum", "Drum" },
            { "statue", "Jade Statue" }, { "grave", "Grave" }, { "cage", "Cage" },
            { "anchor", "Anchor" }, { "signpost", "Signpost" }, { "scroll", "Scroll" },
            { "shovel", "Shovel" },
        } },
        { name = "Nature", props = {
            { "mushroom", "Giant Mushroom" }, { "flower", "Flowers" }, { "bush", "Bush" },
        } },
        { name = "Professions", props = {
            { "alchemy", "Alchemy Table" }, { "fishing", "Fishing Gear" },
        } },
        { name = "Buildings", props = {
            { "cottage", "Cottage" }, { "beertent", "Beer Tent" }, { "pavilion", "Pavilion" },
            { "bigtent", "Large Tent" }, { "stable", "Stable" }, { "doghouse", "Doghouse" },
            { "outhouse", "Outhouse" },
        } },
        -- Camp staff: live creatures, own cap, separate from the prop gauge.
        { name = "Camp staff", staff = true, props = {
            { "banker", "Goblin Banker" }, { "merchant", "Goblin Merchant" },
            { "barkeep", "Barmaid" },
            { "guard-human", "Human Guard" }, { "guard-orc", "Orc Guard" },
            { "steward", "Camp Steward" },   -- repack v1.7.0
        } },
    },
}

-- Category names for the first dropdown.
function WLP.WarbandProps.CategoryNames()
    local out = {}
    for i, cat in ipairs(WLP.WarbandProps.categories) do out[i] = cat.name end
    return out
end

-- True when that category holds camp staff rather than scenery.
function WLP.WarbandProps.IsStaff(catName)
    for _, cat in ipairs(WLP.WarbandProps.categories) do
        if cat.name == catName then return cat.staff == true end
    end
    return false
end

-- {text=label, value=key} choices for one category name (nil if unknown).
function WLP.WarbandProps.PropChoices(catName)
    for _, cat in ipairs(WLP.WarbandProps.categories) do
        if cat.name == catName then
            local out = {}
            for i, p in ipairs(cat.props) do out[i] = { text = p[2], value = p[1] } end
            return out
        end
    end
    return nil
end
