ifeq ($(CONFIG_SEC_A73XQ_PROJECT),y)
obj-$(CONFIG_DIRECT_CHARGING)			+= sec-direct-charger.o
sec-direct-charger-$(CONFIG_DIRECT_CHARGING)	+= a73xq/sb_pass_through.o a73xq/sec_direct_charger.o
else
obj-$(CONFIG_DIRECT_CHARGING)			+= sec-direct-charger.o
sec-direct-charger-$(CONFIG_DIRECT_CHARGING)	+= sec_direct_charger.o
endif

ccflags-y := -Wformat

ifeq ($(CONFIG_SEC_A73XQ_PROJECT),y)
obj-$(CONFIG_BATTERY_SAMSUNG)			+= sec-battery.o
obj-$(CONFIG_BATTERY_SAMSUNG)			+= a73xq/sb_wireless.o
obj-$(CONFIG_SEC_PD)				+= a73xq/sec_pd.o
obj-$(CONFIG_UPDATE_BATTERY_DATA)		+= a73xq/sec_battery_data.o
sec-battery-$(CONFIG_BATTERY_LOGGING)		+= a73xq/battery_logger.o a73xq/sb_batt_dump.o
sec-battery-$(CONFIG_BATTERY_SAMSUNG)		+= a73xq/sec_charging_modprobe.o a73xq/sec_battery.o a73xq/sec_battery_vote.o a73xq/sec_battery_thermal.o a73xq/sec_battery_sysfs.o a73xq/sec_battery_dt.o a73xq/sec_battery_ttf.o a73xq/sec_adc.o a73xq/sec_cisd.o a73xq/sb_full_soc.o
sec-battery-$(CONFIG_ENG_BATTERY_CONCEPT)	+= a73xq/sb_checklist_app.o
sec-battery-$(CONFIG_STEP_CHARGING)		+= a73xq/sec_step_charging.o
sec-battery-$(CONFIG_WIRELESS_AUTH)		+= a73xq/sec_battery_misc.o
sec-battery-$(CONFIG_WIRELESS_CHARGING)		+= a73xq/sec_battery_wc.o
sec-battery-$(CONFIG_WIRELESS_TX_MODE)		+= a73xq/sb_tx.o
else
obj-$(CONFIG_BATTERY_SAMSUNG)		+= sec-battery.o
obj-$(CONFIG_SEC_PD)			+= sec_pd.o
obj-$(CONFIG_UPDATE_BATTERY_DATA)	+= sec_battery_data.o
sec-battery-$(CONFIG_BATTERY_CISD)	+= sec_cisd.o
sec-battery-$(CONFIG_BATTERY_SAMSUNG)	+= sec_battery.o sec_battery_vote.o sec_battery_thermal.o sec_battery_sysfs.o sec_battery_dt.o sec_battery_ttf.o sec_adc.o sb_full_soc.o
sec-battery-$(CONFIG_STEP_CHARGING)	+= sec_step_charging.o
sec-battery-$(CONFIG_WIRELESS_AUTH)	+= sec_battery_misc.o
sec-battery-$(CONFIG_WIRELESS_CHARGING)	+= sec_battery_wc.o
endif

ifeq ($(CONFIG_SEC_KUNIT), y)
ifeq ($(CONFIG_SEC_A73XQ_PROJECT),y)
ifeq ($(CONFIG_BATTERY_SAMSUNG), m)
GCOV_PROFILE_sec_battery.o	:= y
GCOV_PROFILE_sec_battery_thermal.o	:= y
GCOV_PROFILE_sec_battery_vote.o	:= y
GCOV_PROFILE_sec_adc.o		:= y
GCOV_PROFILE_sec_battery_sysfs.o	:= y
GCOV_PROFILE_sec_battery_ttf.o	:= y
GCOV_PROFILE_sec_battery_dt.o	:= y
GCOV_PROFILE_sec_cisd.o		:= y
ifneq ($(CONFIG_WIRELESS_CHARGING), n)
GCOV_PROFILE_sec_battery_wc.o	:= y
endif
ifneq ($(CONFIG_STEP_CHARGING), n)
GCOV_PROFILE_sec_step_charging.o	:= y
endif
ifneq ($(CONFIG_WIRELESS_AUTH), n)
GCOV_PROFILE_sec_battery_misc.o	:= y
endif
else
GCOV_PROFILE_sec_battery.o	:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_battery_wc.o	:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_battery_thermal.o	:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_battery_vote.o		:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_cisd.o		:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_adc.o		:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_battery_sysfs.o	:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_battery_ttf.o	:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_step_charging.o	:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_battery_dt.o	:= $(CONFIG_SEC_KUNIT)
GCOV_PROFILE_sec_battery_misc.o	:= $(CONFIG_SEC_KUNIT)
endif
GCOV_PROFILE_sec_pd.o	:= $(CONFIG_SEC_KUNIT)
ifeq ($(CONFIG_UML), y)
endif
endif
endif
ccflags-y := -Wformat
