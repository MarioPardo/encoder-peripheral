# Mapping enc_a to Shield Pin IO0 (Pin L15), enc_b to L14
set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { enc_a_0 }];
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { enc_b_0 }];