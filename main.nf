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
  memory { 10.GB + (1.GB * Math.round(BYTES.toInteger()  / 1000 / 1000 / 1000 * 5) *  task.attempt ) } 
  time { 8.hour * task.attempt }
  publishDir "$params.outdir", mode: 'copy', overwrite: true
  input:
    path ''
    path 'models/DAPI'
    val BYTES
  output:
    path 'transcripts_cellpose.csv'


  """
    cp /app/notebook.ipynb  .
    jupyter nbconvert \
      --execute \
      --to html \
      notebook.ipynb   
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
        --width $params.width \
        --height $params.height \
        --overlap $params.overlap\
        --min-qv $params.qv\
        --out-dir out/ \
        --minimal-transcripts $params.minimal_transcripts_per_tile
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
    output:
        path "out/segmentation.csv"

    """
    mkdir out
    JULIA_NUM_THREADS=$task.cpus baysor run \
        -x x_location\
        -y y_location\
        -z z_location \
        -g feature_name \
        --min-molecules-per-cell $params.min_molecules_per_cell \
        -o out/ \
        -p \
        --scale $params.scale \
        --prior-segmentation-confidence $params.prior_segmentation_confidence \
        transcripts.csv \
        :cell_id

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
        --threshold $params.merge_threshold \
        --additional-columns x\
        --additional-columns y\
        --additional-columns z\
        --additional-columns qv\
        --additional-columns overlaps_nucleus\
        --additional-columns gene\
        --outfile transcripts.csv

    """
}


process dumpParameters {
  publishDir "$params.outdir", mode: 'copy', overwrite: true
  output:
    path "parameter.txt"

  """
  cat > parameter.txt << EOF
  # Parameters

  ## Input 
  - xenium_path: $params.xenium_path

  ## Baysor
  - min_molecules_per_cell: $params.min_molecules_per_cell
  - scale: $params.scale
  - prior_segmentation_confidence: $params.prior_segmentation_confidence

  ## Merging
  - merge_threshold: $params.merge_threshold
  - outdir: $params.outdir

  EOF
  """
}

workflow {
  XENIUM =  Channel.fromPath( params.xenium_path, type: 'dir')
  CELLPOSE_MODEL = file("$baseDir/dataset/sequences.fa")
  
  size = getImageSize(XENIUM)

  nuclearSegmentation(XENIUM, CELLPOSE_MODEL, size) \
  | tileXenium \
  | flatten \
  | filter{ it.size()>0 } \
  | getNumberOfTranscripts \
  | Baysor \
  | collect \
  | mergeTiles

  dumpParameters()
}
