# Generated from server shop reward tables. Run scripts/sync_shop_pack_loot.cjs to update.
extends RefCounted

const PACKS = {
  "lure_pack": {
    "draws": 5,
    "rewards": [
      {
        "item_id": "bait",
        "category": "lure",
        "chance": 0.6
      },
      {
        "item_id": "worm_bait",
        "category": "lure",
        "chance": 0.18
      },
      {
        "item_id": "shiny_worm_bait",
        "category": "lure",
        "chance": 0.16
      },
      {
        "item_id": "minnow_bait",
        "category": "lure",
        "chance": 0.055
      },
      {
        "item_id": "shrimp_bait",
        "category": "lure",
        "chance": 0.005
      }
    ]
  },
  "basic_items_pack": {
    "draws": 1,
    "rewards": [
      {
        "item_id": "messy_brown_hair",
        "category": "hair",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "blue_baseball_cap",
        "category": "hat",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "green_baseball_cap",
        "category": "hat",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "red_baseball_cap",
        "category": "hat",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_blue_shirt",
        "category": "shirt",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_red_shirt",
        "category": "shirt",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_white_shirt",
        "category": "shirt",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_black_shirt",
        "category": "shirt",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_heart_shirt",
        "category": "shirt",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_gray_shirt",
        "category": "shirt",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_maroon_shirt",
        "category": "shirt",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_black_pants",
        "category": "pants",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_light_gray_pants",
        "category": "pants",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_navy_pants",
        "category": "pants",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_brown_pants",
        "category": "pants",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_green_pants",
        "category": "pants",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_pink_pants",
        "category": "pants",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_brown_shoes",
        "category": "shoes",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_black_shoes",
        "category": "shoes",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_red_shoes",
        "category": "shoes",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_blue_shoes",
        "category": "shoes",
        "chance": 0.045454545454545456
      },
      {
        "item_id": "basic_yellow_shoes",
        "category": "shoes",
        "chance": 0.045454545454545456
      }
    ]
  },
  "hairpack": {
    "draws": 1,
    "rewards": [
      {
        "item_id": "black_afro",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "black_slick_hair",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "black_combed_hair",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "frosty_hair",
        "category": "hair",
        "chance": 0.01
      },
      {
        "item_id": "flaming_hair",
        "category": "hair",
        "chance": 0.01
      },
      {
        "item_id": "old_men_hair",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "brown_fringe",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "brown_combed_hair",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "blonde_hair",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "brunette_hair",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "crazy_hair",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "black_spiky_hair",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "chestnut_curtains",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "supernova_hair",
        "category": "hair",
        "chance": 0.01
      },
      {
        "item_id": "chestnut_bob",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "ginger_ponytail",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "ginger_pigtails",
        "category": "hair",
        "chance": 0.06921428571428571
      },
      {
        "item_id": "baby_hair",
        "category": "hair",
        "chance": 0.001
      }
    ]
  },
  "prestige_coloured_block_pack": {
    "draws": 5,
    "rewards": [
      {
        "item_id": "ps_blue_block",
        "category": "block",
        "chance": 0.2
      },
      {
        "item_id": "ps_green_block",
        "category": "block",
        "chance": 0.2
      },
      {
        "item_id": "ps_purple_block",
        "category": "block",
        "chance": 0.2
      },
      {
        "item_id": "ps_red_block",
        "category": "block",
        "chance": 0.2
      },
      {
        "item_id": "ps_yellow_block",
        "category": "block",
        "chance": 0.2
      }
    ]
  }
}
