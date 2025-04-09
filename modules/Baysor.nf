include {BaysorConfig}  from '../modules/BaysorConfig'

process tileXenium {
  container 'docker://maximilianheeg/tile-xenium:v0.1.2'
  cpus 8
  memory { 10.GB * task.attempt }
  time { 2.hour * task.attempt }
  errorStrategy 'retry'
  maxRetries 3
  input:
    path infile
  output:
    path 'out/X*.csv'


  """
    tile-xenium ${infile} \
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

process runBaysor {
    container 'docker://maximilianheeg/baysor:v0.6.2'
    cpus 8
    // Calcutelate the required memory dynamically based on the number of transcripts
    // These values are estimates from the benchmarking that I did.
    memory { 10.GB + (1.GB * Math.round(TRANSCRIPTS.toInteger()  / 1000000 * 20) *  task.attempt ) }
    time { 12.hour * task.attempt }
    errorStrategy 'retry'
    maxRetries 3
    input:
        tuple val(TRANSCRIPTS), path("transcripts.csv"), path("config.toml")
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
    container 'docker://maximilianheeg/merge-baysor:v0.1.1'
    cpus 8
    memory { 10.GB * task.attempt }
    time { 2.hour * task.attempt }
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

workflow Baysor {
    take:
        ch_xenium_output
        ch_nuclear_segmentation

    main:
        ch_baysor_config = BaysorConfig(ch_xenium_output)

        ch_baysor_segmentation = tileXenium(ch_nuclear_segmentation) \
            | flatten \
            | filter{ it.size()>0 } \
            | getNumberOfTranscripts \
            | combine(ch_baysor_config) \
            | runBaysor \
            | collect \
            | mergeTiles


    emit:
        transcripts  = ch_baysor_segmentation
        config       = ch_baysor_config

}
