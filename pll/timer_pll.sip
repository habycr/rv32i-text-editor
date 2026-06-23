set_global_assignment -entity "timer_pll" -library "lib_timer_pll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "timer_pll" -library "lib_timer_pll" -name IP_TOOL_VERSION "18.0"
set_global_assignment -entity "timer_pll" -library "lib_timer_pll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_timer_pll" -name SPD_FILE [file join $::quartus(sip_path) "timer_pll.spd"]

set_global_assignment -library "lib_timer_pll" -name MISC_FILE [file join $::quartus(sip_path) "timer_pll_sim/timer_pll.vo"]
