// Nextflow pipeline for 10x segmentation


process getImageSize {
  input:
    path ''
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

process nuclearSegmentation {
  cpus { 12 * task.attempt }
  memory { 10.GB + (1.GB * Math.round(BYTES.toLong()/ 1000 / 1000 / 1000 * 5) *  task.attempt ) } 
  time { 8.hour * task.attempt }
  publishDir "$params.outdir", mode: 'copy', overwrite: true
  errorStrategy 'retry'
  maxRetries 3
  input:
    path ''
    path 'models/DAPI'
    val BYTES
  output:
    path 'transcripts_cellpose.csv'


  """
    cp $baseDir/scripts/nuclear_segmentation.ipynb  .
    jupyter nbconvert \
      --execute \
      --to html \
      nuclear_segmentation.ipynb   
  """
}

process tileXenium {
  cpus 8
  memory { 10.GB * task.attempt }
  time { 2.hour * task.attempt }
  input:
    path 'transcripts.csv'
  output:
    path 'out/X*.csv'


  """
    tile-xenium transcripts.csv \
        --width $params.tile.width \
        --height $params.tile.height \
        --overlap $params.tile.overlap\
        --min-qv $params.tile.qv\
        --out-dir out/ \
        --minimal-transcripts $params.tile.minimal_transcripts
  """
}


process getNumberOfTranscripts {
    input:
        path 'transcripts.csv'
    output:
        tuple env(TRANSCRIPTS), path("transcripts.csv")
    '''
    TRANSCRIPTS=$(cat transcripts.csv | wc -l )
    '''

}


process createBaysorConfig {
    output:
      path "config.toml"

    """
    cat > config.toml << EOF
    [data]
    x = "x_location"
    y = "y_location"
    z = "z_location"
    gene = "feature_name"
    min_molecules_per_cell = $params.baysor.min_molecules_per_cell 
  
    [segmentation]
    scale = $params.baysor.scale
    scale_std = "$params.baysor.scale_std"
    prior_segmentation_confidence = $params.baysor.prior_segmentation_confidence
    new_component_weight = $params.baysor.new_component_weight
    EOF
    """
}


process Baysor {
    cpus 8
    // Calcutelate the required memory dynamically based on the number of transcripts
    // These values are estimates from the benchmarking that I did.
    memory { 10.GB + (1.GB * Math.round(TRANSCRIPTS.toInteger()  / 1000000 * 20) *  task.attempt ) } 
    time { 12.hour * task.attempt }
    errorStrategy 'retry'
    maxRetries 3
    input:
        tuple val(TRANSCRIPTS), path("transcripts.csv")
        path "config.toml"
    output:
        path "out/segmentation.csv"

    """
    mkdir out

    JULIA_NUM_THREADS=$task.cpus baysor run \
        -c config.toml \
        -o out/ \
        -p \
        transcripts.csv \
        :cell_id \
    """
}

process mergeTiles {
    cpus 8
    memory { 10.GB * task.attempt }
    time { 2.hour * task.attempt }
    publishDir "$params.outdir", mode: 'copy', overwrite: true
    input:
        path "*transcripts.csv"
    output:
        path "transcripts.csv"

    """
    merge-baysor *transcripts.csv \
        --threshold $params.merge.iou_threshold \
        --additional-columns x\
        --additional-columns y\
        --additional-columns z\
        --additional-columns qv\
        --additional-columns overlaps_nucleus\
        --additional-columns gene\
        --outfile transcripts.csv

    """
}

process diagnosticPlots {
  input:
    path "data/transcripts.csv"
    path "data/transcripts_cellpose.csv"
  output:
    path 'diagnostics.html'
  publishDir "$params.outdir", mode: 'copy', overwrite: true

  """
    cp $baseDir/scripts/diagnostics.ipynb  .
    jupyter nbconvert \
      --execute \
      --to html \
      diagnostics.ipynb   
  """
}

process dumpParameters {
  publishDir "$params.outdir", mode: 'copy', overwrite: true
  output:
    path "parameter.txt"

  """
  cat > parameter.txt << EOF
  # Parameters

  ## Input / Outout
  - xenium_path: $params.xenium_path
  - outdir: $params.outdir

  ## Tile creation
  - width: $params.tile.width
  - height: $params.tile.height
  - overlap: $params.tile.overlap
  - minimal_transcripts: $params.tile.minimal_transcripts

  ## Baysor
  - min_molecules_per_cell: $params.baysor.min_molecules_per_cell
  - scale: $params.baysor.scale
  - prior_segmentation_confidence: $params.baysor.prior_segmentation_confidence

  ## Merging
  - merge_threshold: $params.merge.iou_threshold
  EOF
  """
}

workflow {
  XENIUM =  Channel.fromPath( params.xenium_path, type: 'dir')
  CELLPOSE_MODEL = file("$baseDir/models/DAPI")
  
  size = getImageSize(XENIUM)
  baysor_config = createBaysorConfig()

  nuclear_segmentation = nuclearSegmentation(XENIUM, CELLPOSE_MODEL, size)

  baysor_segmentation = tileXenium(nuclear_segmentation) \
  | flatten \
  | filter{ it.size()>0 }
  | getNumberOfTranscripts
  
  baysor_segmentation = Baysor(baysor_segmentation, baysor_config)
  | collect \
  | mergeTiles

  diagnosticPlots(baysor_segmentation, nuclear_segmentation)

  dumpParameters()
}
