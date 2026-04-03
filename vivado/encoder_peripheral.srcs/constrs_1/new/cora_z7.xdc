# =============================================================
# Cora Z7 - Phase 2 Constraints
# =============================================================

# BTN0 -> enc_a (D20)
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { enc_a_0 }];

# BTN1 -> enc_b (D19)
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { enc_b_0 }];
