USER_PERIPHERAL_2 = uart
USER_PERIPHERAL_3 = game_pmod
USER_PERIPHERAL_4 = vga_gfx.test
USER_PERIPHERAL_5 = freq_synth.test
USER_PERIPHERAL_6 =
USER_PERIPHERAL_7 =
USER_PERIPHERAL_8 =
USER_PERIPHERAL_9 = test_stevej_watchdog
USER_PERIPHERAL_10 =
USER_PERIPHERAL_11 =
USER_PERIPHERAL_12 =
USER_PERIPHERAL_13 =
USER_PERIPHERAL_14 =
USER_PERIPHERAL_15 =
USER_PERIPHERAL_16 =
USER_PERIPHERAL_17 =
USER_PERIPHERAL_18 =
USER_PERIPHERAL_19 =
USER_PERIPHERAL_20 =
USER_PERIPHERAL_21 = matt_pwm.test
USER_PERIPHERAL_22 =
USER_PERIPHERAL_23 =
USER_PERIPHERAL_24 =
USER_PERIPHERAL_25 =
USER_PERIPHERAL_26 =
USER_PERIPHERAL_27 =
USER_PERIPHERAL_28 =
USER_PERIPHERAL_29 =
USER_PERIPHERAL_30 = spi
USER_PERIPHERAL_31 =

.PHONY: clean core prog peri_test_% peri_num_%

%-results.xml:
	@make -f test_$*.mk clean
	make -f test_$*.mk
	@mv results.xml $@
	@mv sim_build/rtl/tb*.fst $*-rtl.fst || true
	@mv sim_build/gl/tb*.fst $*-gl.fst || true

peri-%.xml:
	@make -f test_basic.mk clean
	MODULE=user_peripherals.$* make -f test_basic.mk || true
	@if [ ! -f results.xml ]; then echo '<failure message="$* failed (crashed)" />' > results.xml; fi
	@mv results.xml $@
	@mv sim_build/rtl/tb.fst $*-rtl.fst || true
	@mv sim_build/gl/tb.fst $*-gl.fst || true

clean:
	rm *results.xml peri-*.xml *.fst sim_build/rtl/tb.fst sim_build/gl/tb.fst || true

core: clean basic-results.xml
	@cat *results.xml > results.xml

prog: clean prog-results.xml
	@cat *results.xml > results.xml

peri_test_%: peri-%.xml
	@:

.SECONDEXPANSION:
peri_num_%: clean $$(addprefix peri_test_,$$($$(addprefix USER_PERIPHERAL_,$$*)))
	@if [ "$(USER_PERIPHERAL_$*)" != "" ]; then cat peri-*.xml; else echo '<testsuites name="results" />'; fi > results.xml

