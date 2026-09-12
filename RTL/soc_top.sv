# -----------------------------------------------------------------------------
## CLIC Minimal FPGA Constraints File (.xdc)
## Target Board: Digilent Basys 3 (Artix-7 xc7a35tcpg236-1)
## -----------------------------------------------------------------------------

## 1. System Clock (100 MHz)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports { clk }];

## 2. System Reset (Active Low - Center Push Button)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports { reset_n }];

## 3. Physical External Interrupt Pins (Mapped to Switch 0 and Switch 1)
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports { ext_irq_pins[0] }];
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports { ext_irq_pins[1] }];

## 4. CPU Interrupt Request (Mapped to LED 15 - Far Left)
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports { cpu_int_req }];

## 5. CPU Winning ID (Mapped to LEDs 0-3 - Far Right)
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports { cpu_int_id[0] }];
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports { cpu_int_id[1] }];
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports { cpu_int_id[2] }];
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports { cpu_int_id[3] }];