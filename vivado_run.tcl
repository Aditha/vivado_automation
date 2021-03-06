#!/usr/bin/tclsh
# author : aditha rajakaruna
# email : aditha102@gmail.com
# - Main --------------------------------------------------
if { [catch {source "inputs.tcl"} errmsg] } {
    puts "vivado_run error : ${errmsg}"
    exit
}
set logdir "./logs"
set outdir "./outputs"
if { [file isdirectory $logdir] } {
    if { $en_newrun == 1 } {
        file delete -force $logdir
        file mkdir $logdir
    }
} else {
    file mkdir $logdir
}
if { [file isdirectory $outdir] } {
    if { $en_newrun == 1 } {
        file delete -force $outdir
        file mkdir $outdir
    }
} else {
    file mkdir $outdir
}
# - Gathering inputs --------------------------------------
if { [catch {set_part $device} errmsg] } {
    puts "vivado_run error : ${errmsg}"
    exit
}
if { $en_newrun == 1 } {
    # - Read RTL models
    foreach rtl_src_path [split $rtl_src_paths ","] {
        set rtl_src_path [string trim $rtl_src_path]
        if { [catch {read_verilog [glob $rtl_src_path/*.v]} errmsg] } {
            puts "vivado_run error : ${errmsg}"
            exit
        }
    }
    # - Read constraint files
    foreach xdc_src_path [split $xdc_src_paths ","] {
        set xdc_src_path [string trim $xdc_src_path]
        if { [catch {read_xdc [glob $xdc_src_path/*.xdc]} errmsg] } {
            puts "vivado_run error : ${errmsg}"
            exit
        }
    }
    # TODO Read and upgrade ip cores
}
# - Synthesis ---------------------------------------------
if { $en_synth == 1 } {
    synth_design -top $top_design -flatten_hierarchy $s_flattern_hierarchy \
        -directive $s_syn_directive -verbose
    write_checkpoint -force $outdir/post_synth
    set en_newrun 1
    report_utilization -file $logdir/post_synth_util.rpt
    report_timing -sort_by group -max_paths 5 -path_type \
        summary -file $logdir/post_synth_timing.rpt
}
# - Place -------------------------------------------------
if { $en_place == 1 } {
    if { $en_newrun == 0 } {
        if { [catch {open_checkpoint $outdir/post_synth.dcp} errmsg] } {
            puts "vivado_run error : ${errmsg}"
            exit
        }
    }
    opt_design -verbose
    power_opt_design -verbose
    place_design -directive $s_place_directive -verbose
    phys_opt_design -verbose
    write_checkpoint -force $outdir/post_place
    set en_newrun 1
    report_clock_utilization -file $logdir/clock_util.rpt
    report_utilization -file $logdir/post_place_util.rpt
    report_timing -sort_by group -max_paths 5 -path_type \
        summary -file $logdir/post_place_timing.rpt
}
# - Route -------------------------------------------------
if { $en_route == 1 } {
    if { $en_newrun == 0 } {
        if { [catch {open_checkpoint $outdir/post_place.dcp} errmsg] } {
            puts "vivado_run error : ${errmsg}"
            exit
        }
    }
    route_design
    write_checkpoint -force $outdir/post_route
    report_timing_summary -file $logdir/post_route_timing_summary.rpt
    report_utilization -file $logdir/post_route_util.rpt
    report_power -file $logdir/post_route_power.rpt
    report_drc -file $logdir/post_imp_drc.rpt
    write_verilog -force "${outdir}/${top_design}_impl_netlist.v"
    write_xdc -no_fixed_only -force "${outdir}/${top_design}_impl.xdc"
}
# - Bit File Generation -----------------------------------
if { $en_bitgen == 1 } {
    if { $en_newrun == 0 } {
        if { [catch {open_checkpoint $outdir/post_route.dcp} errmsg] } {
            puts "vivado_run error : ${errmsg}"
            exit
        }
    }
    if { [catch {write_bitstream "${outdir}/${top_design}_design.bit"} errmsg] } {
        puts "vivado_run error : ${errmsg}"
        exit
    }
}
