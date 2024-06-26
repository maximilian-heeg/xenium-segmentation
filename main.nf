// Nextflow pipeline for 10x segmentation

include {Logo}                      from './modules/Logo'
include {Baysor}                    from './modules/Baysor'
include {Report}                    from './modules/Report'


workflow {
  Logo()

  // Define input channels
  ch_xenium_output =  Channel.fromPath( params.xenium_path, type: 'dir', checkIfExists: true)
  ch_xenium_transcripts = Channel.fromPath( params.xenium_path + "/transcripts.parquet", checkIfExists: true)



  // Run Baysor
  wf_baysor_segmentation = Baysor (
      ch_xenium_output, 
      ch_xenium_transcripts
  )
  ch_baysor_segmentation = wf_baysor_segmentation.transcripts
  ch_baysor_config       = wf_baysor_segmentation.config


  // Create a report
  Report(
    ch_xenium_output,
    ch_baysor_segmentation,
    ch_xenium_transcripts,
    ch_baysor_config
  )
}
