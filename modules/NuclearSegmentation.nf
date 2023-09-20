process getImageSize {
  container  'docker://maximilianheeg/docker-cellpose:v2.2.3'
  input:
    path 'data'
  output:
    stdout
  script:
  """
    #!/usr/bin/env python
    import tifffile

    tif = tifffile.TiffFile('data/morphology_mip.ome.tif')
    page = tif.pages[0]  # get shape and dtype of image in first page
    pixel = page.shape[0] * page.shape[1]
    bytes = pixel * 16
    print(bytes)
  """
}

process cellpose {
  container 'docker://maximilianheeg/docker-cellpose:v2.2.3'
  cpus { 12 * task.attempt }
  memory { 10.GB + (1.GB * Math.round(BYTES.toLong()/ 1000 / 1000 / 1000 * 7) *  task.attempt ) } 
  time { 8.hour * task.attempt }
  publishDir "$params.outdir", mode: 'copy', overwrite: true,  pattern: '*.csv'
  errorStrategy 'retry'
  maxRetries 0
  input:
    path 'nuclear_segmentation.ipynb'
    path 'data'
    path 'models/DAPI'
    val BYTES
  output:
    path 'transcripts_cellpose.csv', emit: transcripts
    path 'nuclear_segmentation.nbconvert.ipynb', emit: notebook


  """
    jupyter nbconvert --to notebook --execute nuclear_segmentation.ipynb
  """
}

workflow NuclearSegmentation {
    take:
        ch_xenium_output
        ch_cellpose_model

    main:
        ch_size = getImageSize(ch_xenium_output)

        ch_segmentation_notebook = Channel.fromPath("$baseDir/scripts/nuclear_segmentation.ipynb")

        process_nuclear_segmentation = cellpose(
            ch_segmentation_notebook,
            ch_xenium_output, 
            ch_cellpose_model, 
            ch_size
        )

        ch_nuclear_segmentation = process_nuclear_segmentation.transcripts
        ch_notebook = process_nuclear_segmentation.notebook

    emit:
        transcripts = ch_nuclear_segmentation
        notebook    = ch_notebook
}