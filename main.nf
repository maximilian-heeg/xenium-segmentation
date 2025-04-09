// Nextflow pipeline for 10x segmentation

include {Logo}                      from './modules/Logo'
include {Baysor}                    from './modules/Baysor'
include {XeniumRanger}              from './modules/XeniumRanger'
include {Instanseg}                 from './modules/Instanseg'

workflow {
    Logo()

    // Define input channels
    ch_xenium_output =  Channel.fromPath( params.xenium_path, type: 'dir', checkIfExists: true)
    ch_xenium_transcripts = Channel.fromPath( params.xenium_path + "/transcripts.parquet", checkIfExists: true)


    if (params.segmentation_method == 'baysor') {
        // Run Baysor
        wf_baysor_segmentation = Baysor (
            ch_xenium_output,
            ch_xenium_transcripts
        )
        ch_baysor_segmentation = wf_baysor_segmentation.transcripts
        ch_baysor_config       = wf_baysor_segmentation.config

        wf_xenium_ranger = XeniumRanger(
            ch_baysor_segmentation,
            ch_xenium_output
        )

    } else if (params.segmentation_method == 'instanseg') {
        Instanseg(
            ch_xenium_output
        )
    } else {
        // Handle invalid parameter value
        error "Invalid segmentation_method: '${params.segmentation_method}'. Please choose 'baysor' or 'instanseg'."
    }
}
