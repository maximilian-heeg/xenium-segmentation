// Nextflow pipeline for 10x segmentation

include {Logo}                      from './modules/Logo'
include {Baysor}                    from './modules/Baysor'
include {NuclearSegmentation}       from './modules/NuclearSegmentation'
include {Report}                    from './modules/Report'


workflow {
  Logo()

  // Define input channels
  ch_xenium_output =  Channel.fromPath( params.xenium_path, type: 'dir', checkIfExists: true)
  ch_cellpose_model = file("$baseDir/models/DAPI")

  
  // Run nuclear segmentation
  wf_nuclear_segmentation = NuclearSegmentation(
      ch_xenium_output,
      ch_cellpose_model

  )
  ch_nuclear_segmentation = wf_nuclear_segmentation.transcripts
  ch_nuclear_segmentation_notebook = wf_nuclear_segmentation.notebook


  // Run Baysor
  wf_baysor_segmentation = Baysor (
      ch_xenium_output, 
      ch_nuclear_segmentation
  )
  ch_baysor_segmentation = wf_baysor_segmentation.transcripts
  ch_baysor_config       = wf_baysor_segmentation.config


  // Create a report
  Report(
    ch_xenium_output,
    ch_baysor_segmentation,
    ch_nuclear_segmentation,
    ch_nuclear_segmentation_notebook, 
    ch_baysor_config
  )
}
