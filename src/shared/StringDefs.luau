--!strict
-- StringDefs.luau
-- All UI strings in Indonesian.
-- LocalizationBridge uses this as a fallback (and primary source during development).
-- For multi-language support, mirror these into a LocalizationTable inside LocalizationService.
-- Format params use {paramName} syntax: e.g. "Ada {count} pemain" with { count = 5 } → "Ada 5 pemain"

local StringDefs: { [string]: string } = {

	-- ─── HUD ─────────────────────────────────────────────────────────────────────

	UI_LABEL_ZONE        = "Hub",
	UI_MINIMAP_LABEL     = "Peta",
	UI_PLAYERS_COUNT     = "{count} Pemain",
	UI_SHARDS_LABEL      = "Serpihan",
	UI_BUTTON_SCAN       = "SCAN",
	UI_BUTTON_SHOP       = "Toko",
	UI_BUTTON_COMPENDIUM = "Kompendium",
	UI_BUTTON_BUY        = "Beli",
	UI_BUTTON_CLOSE      = "Tutup",
	UI_CAPTURE_SUCCESS   = "Berhasil ditangkap!",
	UI_CAPTURE_FAIL      = "Hantu kabur...",

	-- ─── Zone names ───────────────────────────────────────────────────────────────

	ZONE_Kuburan_NAME      = "Kuburan",
	ZONE_KampungTua_NAME   = "Kampung Tua",
	ZONE_HutanBambu_NAME   = "Hutan Bambu",
	ZONE_PantaiSepi_NAME   = "Pantai Sepi",
	ZONE_KuburanCina_NAME  = "Kuburan Cina",
	ZONE_SawahHaunted_NAME = "Sawah Haunted",

	-- ─── Shop ────────────────────────────────────────────────────────────────────

	UI_SHOP_TITLE               = "Toko",
	UI_SHOP_TAB_BOTTLES         = "Botol",
	UI_SHOP_TAB_COSMETICS       = "Kosmetik",
	UI_SHOP_TAB_BATTLEPASS      = "Battle Pass",
	UI_SHOP_TAB_BOOSTS          = "Boost",
	UI_SHOP_FREE_DAILY          = "Gratis Harian",
	UI_SHOP_ROBUX_PRICE         = "Robux",
	UI_SHOP_BP_TITLE            = "Battle Pass",
	UI_SHOP_BP_TIER             = "Tier {tier}",
	UI_SHOP_BP_REWARD_PLACEHOLDER = "Hadiah",
	UI_SHOP_ERROR_GENERIC       = "Terjadi kesalahan, coba lagi.",
	UI_SHOP_ERROR_SHARDS        = "Serpihan tidak cukup.",
	UI_SHOP_ERROR_FULL          = "Kapasitas botol penuh.",

	-- ─── Bottle names ─────────────────────────────────────────────────────────────

	BOTTLE_BotolBiasa_NAME    = "Botol Biasa",
	BOTTLE_BotolKacaBiru_NAME = "Botol Kaca Biru",
	BOTTLE_BotolEmas_NAME     = "Botol Emas",
	BOTTLE_BotolKristal_NAME  = "Botol Kristal",
	BOTTLE_BotolRetak_NAME    = "Botol Retak",

	-- ─── Gamepasses / boosts ─────────────────────────────────────────────────────

	SHOP_GAMEPASS_VIP       = "VIP Hunter (+10% XP)",
	SHOP_GAMEPASS_BOTTLE    = "Tas Botol Ekstra (+10 kapasitas)",
	SHOP_GAMEPASS_AUTOSHARD = "Kolektor Serpihan Otomatis",
	SHOP_BOOST_XP_NAME      = "Boost XP (2 jam)",
	SHOP_SHARDS_100         = "100 Serpihan",
	SHOP_SHARDS_500         = "500 Serpihan",
	SHOP_SHARDS_1500        = "1.500 Serpihan",

	-- ─── Compendium ───────────────────────────────────────────────────────────────

	UI_COMPENDIUM_TITLE      = "Kompendiumku",
	UI_COMPENDIUM_OTHER      = "Kompendium {name}",
	UI_COMPENDIUM_CAPTURES   = "Ditangkap: {count}×",
	UI_COMPENDIUM_FIRST_DATE = "Pertama: {date}",

	-- ─── Tutorial ─────────────────────────────────────────────────────────────────

	TUT_STEP0 = "Selamat datang, pemburu hantu! Jelajahi pulau-pulau dan tangkap hantu.",
	TUT_STEP1 = "Tekan SCAN untuk mendeteksi keberadaan hantu di sekitarmu.",
	TUT_STEP2 = "Hantu terdeteksi! Dekati dan interaksi untuk memulai penangkapan.",
	TUT_STEP3 = "Tangkap hantu sebelum ia kabur!",
	TUT_STEP4 = "Berhasil! Cek Kompendium untuk melihat koleksimu.",
	TUT_STEP5 = "Selesai! Jelajahi semua zona dan lengkapi kompendiummu.",

	-- ─── Rank titles ─────────────────────────────────────────────────────────────

	RANK_PEMULA_TITLE      = "Pemula",
	RANK_JAGOAN_TITLE      = "Jagoan",
	RANK_PARANORMAL_TITLE  = "Paranormal",
	RANK_DUKUN_TITLE       = "Dukun",
	RANK_LEGENDA_TITLE     = "Legenda",

	-- ─── Ghost names ─────────────────────────────────────────────────────────────
	-- Common
	GHOST_Pocong_NAME        = "Pocong",
	GHOST_Kuntilanak_NAME    = "Kuntilanak",
	GHOST_WeweGombel_NAME    = "Wewe Gombel",
	GHOST_Banaspati_NAME     = "Banaspati",
	GHOST_SundelBolong_NAME  = "Sundel Bolong",
	GHOST_Toyol_NAME         = "Toyol",
	GHOST_Tuyul_NAME         = "Tuyul",
	GHOST_LeakWeak_NAME      = "Leak (Lemah)",
	GHOST_GenderuwoJr_NAME   = "Genderuwo Jr.",
	GHOST_Jenglot_NAME       = "Jenglot",
	-- Rare
	GHOST_Rangda_NAME         = "Rangda",
	GHOST_OrangBunian_NAME    = "Orang Bunian",
	GHOST_HantuRaya_NAME      = "Hantu Raya",
	GHOST_BabiNgepet_NAME     = "Babi Ngepet",
	GHOST_Palasik_NAME        = "Palasik",
	GHOST_Penanggalan_NAME    = "Penanggalan",
	GHOST_AswangMild_NAME     = "Aswang (Ringan)",
	GHOST_ManananggalHalf_NAME = "Manananggal Setengah",
	GHOST_KraSue_NAME         = "Kra-Sue",
	GHOST_PhiPop_NAME         = "Phi Pop",
	-- Epic
	GHOST_NyiBlorong_NAME    = "Nyi Blorong",
	GHOST_BataraKala_NAME    = "Batara Kala",
	GHOST_RangdaTrue_NAME    = "Rangda Sejati",
	GHOST_Mahisasura_NAME    = "Mahisasura",
	GHOST_Leyak_NAME         = "Leyak",
	GHOST_SantetSpecter_NAME = "Hantu Santet",
	GHOST_HantuKopek_NAME    = "Hantu Kopek",
	-- Mythic
	GHOST_NyiRoroKidul_NAME    = "Nyi Roro Kidul",
	GHOST_DewiDurga_NAME       = "Dewi Durga",
	GHOST_BataraGuruShadow_NAME = "Bayangan Batara Guru",

	-- ─── Ghost lore (fill in with actual lore text) ───────────────────────────────
	-- Common
	GHOST_Pocong_LORE        = "Arwah yang terbungkus kain kafan, gentayangan di pemakaman.",
	GHOST_Kuntilanak_LORE    = "Wanita berambut panjang yang menghantui pohon-pohon tua.",
	GHOST_WeweGombel_LORE    = "Hantu penculik anak-anak yang berkeliaran di kampung.",
	GHOST_Banaspati_LORE     = "Bola api misterius yang melayang di sawah malam hari.",
	GHOST_SundelBolong_LORE  = "Arwah wanita dengan lubang di punggungnya.",
	GHOST_Toyol_LORE         = "Jimat kecil berbentuk bayi yang digunakan untuk mencuri.",
	GHOST_Tuyul_LORE         = "Makhluk kecil botak pembawa rezeki curian.",
	GHOST_LeakWeak_LORE      = "Leak dalam wujud lemahnya, belum menguasai kekuatan penuh.",
	GHOST_GenderuwoJr_LORE   = "Anak Genderuwo yang masih belia namun sudah menakutkan.",
	GHOST_Jenglot_LORE       = "Makhluk kecil menyeramkan berwujud manusia kerdil.",
	-- Rare
	GHOST_Rangda_LORE         = "Ratu ilmu hitam dari Bali yang menggerakkan para leak.",
	GHOST_OrangBunian_LORE    = "Makhluk halus yang hidup sejajar dengan manusia namun tak terlihat.",
	GHOST_HantuRaya_LORE      = "Roh pelindung yang berbalik menghantui tuannya.",
	GHOST_BabiNgepet_LORE     = "Manusia jelmaan babi yang mencuri kekayaan di malam hari.",
	GHOST_Palasik_LORE        = "Kepala terbang yang memangsa bayi.",
	GHOST_Penanggalan_LORE    = "Kepala wanita dengan organ dalam menggantung, melayang di malam hari.",
	GHOST_AswangMild_LORE     = "Aswang dalam wujud ringannya, belum sepenuhnya berubah.",
	GHOST_ManananggalHalf_LORE = "Makhluk yang memisahkan tubuh bagian atas untuk berburu.",
	GHOST_KraSue_LORE         = "Kepala terbang dari Thailand yang melintasi batas.",
	GHOST_PhiPop_LORE         = "Roh jahat dari Thailand yang merasuki dan memakan organ dalam.",
	-- Epic
	GHOST_NyiBlorong_LORE    = "Penjaga harta karun bawah laut berwujud setengah ular.",
	GHOST_BataraKala_LORE    = "Dewa waktu dan kematian yang memangsa manusia.",
	GHOST_RangdaTrue_LORE    = "Rangda dalam kekuatan penuhnya — jarang terlihat.",
	GHOST_Mahisasura_LORE    = "Asura berkepala kerbau yang mengamuk di malam hari.",
	GHOST_Leyak_LORE         = "Makhluk sihir tertinggi Bali yang menguasai transformasi.",
	GHOST_SantetSpecter_LORE = "Arwah korban santet yang bangkit mencari balas dendam.",
	GHOST_HantuKopek_LORE    = "Hantu wanita penghisap darah yang bersembunyi di kegelapan.",
	-- Mythic
	GHOST_NyiRoroKidul_LORE    = "Ratu Pantai Selatan, penguasa lautan yang tak terbatas.",
	GHOST_DewiDurga_LORE       = "Dewi kematian dan kehancuran dalam wujud paling murka.",
	GHOST_BataraGuruShadow_LORE = "Bayangan gelap Batara Guru yang muncul saat keseimbangan terganggu.",
}

return StringDefs
