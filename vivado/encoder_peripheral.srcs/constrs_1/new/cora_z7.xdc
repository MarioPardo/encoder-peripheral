# =============================================================
# Cora Z7 - Phase 2 Constraints
# =============================================================

# PMOD JA1 -> enc_a (CLK)
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports { enc_a_0 }];

# PMOD JA2 -> enc_b (DT)
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports { enc_b_0 }];
