/* Custom dwl config.h (based on dwl 0.8 config.def.h)
 * Keybindings mirror the mango config from eon5942/eonsdotfiles. */
#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }
/* appearance */
static const int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;  /* 1 means idle inhibitors will disable idle tracking even if it's surface isn't visible  */
static const int smartgaps                 = 1;  /* 1 means no outer gap when there is only one window */
static int gaps                            = 1;  /* 1 means gaps between windows are added */
static const unsigned int gappx            = 8;  /* gap pixel between windows */
static const unsigned int borderpx         = 2;  /* border pixel of windows */
static const float rootcolor[]             = COLOR(0x000000ff);
static const float bordercolor[]           = COLOR(0x333333ff);
static const float focuscolor[]            = COLOR(0xffffffff);
static const float urgentcolor[]           = COLOR(0xffffffff);
/* This conforms to the xdg-protocol. Set the alpha to zero to restore the old behavior */
static const float fullscreen_bg[]         = {0.0f, 0.0f, 0.0f, 1.0f}; /* You can also use glsl colors */

/* tagging - TAGCOUNT must be no greater than 31 */
#define TAGCOUNT (9)

/* logging */
static int log_level = WLR_ERROR;

static const Rule rules[] = {
	/* app_id             title       tags mask     isfloating   monitor */
	{ "Gimp_EXAMPLE",     NULL,       0,            1,           -1 }, /* Start on currently visible tags floating, not tiled */
	{ "firefox_EXAMPLE",  NULL,       1 << 8,       0,           -1 }, /* Start on ONLY tag "9" */
};

/* layout(s) */
static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[F]",      fair },    /* fair: equal-as-possible grid (mango fair) */
	{ "[]=",      tile },
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* monitors */
static const MonitorRule monrules[] = {
	/* name        mfact  nmaster scale layout       rotate/reflect                x     y
	 * HDMI-A-1 (AOC Q27G42ZE, 2560x1440 preferred) is the primary at the origin;
	 * eDP-1 (laptop panel, 1920x1080) sits edge-to-edge to its right at x=2560,
	 * so the outputs never overlap. */
	{ "HDMI-A-1",  0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   0,    0 },
	{ "eDP-1",     0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   2560, 0 },
	/* default: autoconfigure anything else */
	{ NULL,        0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
};

/* keyboard */
static const struct xkb_rule_names xkb_rules = {
	/* can specify fields: rules, model, layout, variant, options */
	.options = "caps:escape",
};

static const int repeat_rate = 25;
static const int repeat_delay = 600;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 0;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* Super is the main modifier; the mango keymap also uses Alt and Ctrl directly. */
#define MODKEY WLR_MODIFIER_LOGO

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static const char *termcmd[] = { "foot", NULL };
static const char *menucmd[] = { "wofi", "--show", "drun", NULL };
static const char *browsercmd[] = { "librewolf", NULL };
static const char *displaycmd[] = { "wdisplays", NULL };

static const Key keys[] = {
	/* spawn terminal / launcher / browser */
	{ WLR_MODIFIER_ALT,          XKB_KEY_Return,      spawn,            {.v = termcmd} },
	{ WLR_MODIFIER_ALT,          XKB_KEY_space,       spawn,            {.v = menucmd} },
	{ MODKEY,                    XKB_KEY_b,           spawn,            {.v = browsercmd} },

	/* screenshots */
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_s,           spawn,            SHCMD("slurp | grim -g - - | wl-copy") },
	{ MODKEY,                    XKB_KEY_Print,       spawn,            SHCMD("grim - | wl-copy") },

	/* system */
	{ MODKEY,                    XKB_KEY_Escape,      spawn,            SHCMD("systemctl suspend") },
	{ MODKEY,                    XKB_KEY_l,           spawn,            SHCMD("swaylock") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Escape,      spawn,            SHCMD("powermenu") },
	{ MODKEY,                    XKB_KEY_m,           quit,             {0} },

	/* audio */
	{ 0, XKB_KEY_XF86AudioRaiseVolume, spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") },
	{ 0, XKB_KEY_XF86AudioLowerVolume, spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
	{ 0, XKB_KEY_XF86AudioMute,        spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
	{ 0, XKB_KEY_XF86AudioMicMute,     spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") },

	/* brightness */
	{ 0, XKB_KEY_XF86MonBrightnessUp,   spawn, SHCMD("brightnessctl set +5%") },
	{ 0, XKB_KEY_XF86MonBrightnessDown, spawn, SHCMD("brightnessctl set 5%-") },

	/* displays */
	{ MODKEY,                    XKB_KEY_p,           spawn,            {.v = displaycmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_p,           spawn,            SHCMD("chres") },

	/* window management */
	{ WLR_MODIFIER_ALT,          XKB_KEY_q,           killclient,       {0} },
	{ WLR_MODIFIER_ALT,          XKB_KEY_backslash,   togglefloating,   {0} },
	{ WLR_MODIFIER_ALT,          XKB_KEY_f,           togglefullscreen, {0} },

	/* focus and layout */
	{ MODKEY,                    XKB_KEY_Tab,         focusstack,       {.i = +1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Tab,         focusstack,       {.i = -1} },
	{ MODKEY,                    XKB_KEY_j,           focusstack,       {.i = +1} },
	{ MODKEY,                    XKB_KEY_k,           focusstack,       {.i = -1} },
	{ MODKEY,                    XKB_KEY_h,           setmfact,         {.f = -0.05f} },
	{ MODKEY,                    XKB_KEY_l,           setmfact,         {.f = +0.05f} },
	{ MODKEY,                    XKB_KEY_i,           incnmaster,       {.i = +1} },
	{ MODKEY,                    XKB_KEY_d,           incnmaster,       {.i = -1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return,      zoom,             {0} },
	{ MODKEY,                    XKB_KEY_n,           setlayout,        {0} },
	{ MODKEY,                    XKB_KEY_y,           setlayout,        {.v = &layouts[0]} },
	{ MODKEY,                    XKB_KEY_t,           setlayout,        {.v = &layouts[1]} },
	{ MODKEY,                    XKB_KEY_f,           setlayout,        {.v = &layouts[2]} },
	{ MODKEY,                    XKB_KEY_v,           setlayout,        {.v = &layouts[3]} },
	{ MODKEY,                    XKB_KEY_g,           togglegaps,       {0} },

	/* tags: Ctrl+N = view tag, Alt+N = move client to tag */
	{ WLR_MODIFIER_CTRL, XKB_KEY_1, view, {.ui = 1 << 0} },
	{ WLR_MODIFIER_CTRL, XKB_KEY_2, view, {.ui = 1 << 1} },
	{ WLR_MODIFIER_CTRL, XKB_KEY_3, view, {.ui = 1 << 2} },
	{ WLR_MODIFIER_CTRL, XKB_KEY_4, view, {.ui = 1 << 3} },
	{ WLR_MODIFIER_CTRL, XKB_KEY_5, view, {.ui = 1 << 4} },
	{ WLR_MODIFIER_CTRL, XKB_KEY_6, view, {.ui = 1 << 5} },
	{ WLR_MODIFIER_CTRL, XKB_KEY_7, view, {.ui = 1 << 6} },
	{ WLR_MODIFIER_CTRL, XKB_KEY_8, view, {.ui = 1 << 7} },
	{ WLR_MODIFIER_CTRL, XKB_KEY_9, view, {.ui = 1 << 8} },
	{ WLR_MODIFIER_ALT, XKB_KEY_1, tag, {.ui = 1 << 0} },
	{ WLR_MODIFIER_ALT, XKB_KEY_2, tag, {.ui = 1 << 1} },
	{ WLR_MODIFIER_ALT, XKB_KEY_3, tag, {.ui = 1 << 2} },
	{ WLR_MODIFIER_ALT, XKB_KEY_4, tag, {.ui = 1 << 3} },
	{ WLR_MODIFIER_ALT, XKB_KEY_5, tag, {.ui = 1 << 4} },
	{ WLR_MODIFIER_ALT, XKB_KEY_6, tag, {.ui = 1 << 5} },
	{ WLR_MODIFIER_ALT, XKB_KEY_7, tag, {.ui = 1 << 6} },
	{ WLR_MODIFIER_ALT, XKB_KEY_8, tag, {.ui = 1 << 7} },
	{ WLR_MODIFIER_ALT, XKB_KEY_9, tag, {.ui = 1 << 8} },

	/* monitors */
	{ WLR_MODIFIER_ALT|WLR_MODIFIER_SHIFT, XKB_KEY_Left,  focusmon,  {.i = WLR_DIRECTION_LEFT} },
	{ WLR_MODIFIER_ALT|WLR_MODIFIER_SHIFT, XKB_KEY_Right, focusmon,  {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_ALT,             XKB_KEY_Left,  tagmon,    {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_ALT,             XKB_KEY_Right, tagmon,    {.i = WLR_DIRECTION_RIGHT} },

	/* Ctrl-Alt-Backspace and Ctrl-Alt-Fx used to be handled by X server */
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_Terminate_Server, quit, {0} },
	/* Ctrl-Alt-Fx is used to switch to another VT, if you don't know what a VT is
	 * do not remove them.
	 */
#define CHVT(n) { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_XF86Switch_VT_##n, chvt, {.ui = (n)} }
	CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,       {.ui = CurMove} },
	{ 0,      BTN_MIDDLE, togglefullscreen, {0} },
	{ MODKEY, BTN_RIGHT,  moveresize,       {.ui = CurResize} },
};
