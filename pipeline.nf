params.transcripts = 'test.csv'
params.width = 4000
params.height = 4000
params.overlap = 500
params.qv = 20
params.minimal_transcripts_per_tile = 10000
params.outdir = 'results'

process tileXenium {
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


process Baysor {
    cpus 8
    memory { 20.GB * task.attempt }
    time { 12.hour * task.attempt }
    errorStrategy 'retry'
    maxRetries 3
    input:
        path 'transcripts.csv'
    output:
        path "out/segmentation.csv"

    """
    mkdir out
    JULIA_NUM_THREADS=$task.cpus baysor run \
        -x x_location\
        -y y_location\
        -z z_location \
        -g feature_name \
        -m 30 \
        -o out/ \
        -p --prior-segmentation-confidence 0.5 \
        transcripts.csv \
        :cell_id

    """
}

process mergeTiles {
    publishDir "$params.outdir", mode: 'copy', overwrite: true
    input:
        path "*transcripts.csv"
    output:
        path "transcripts.csv"

    """
    merge-baysor *transcripts.csv \
        --threshold 0.2 \
        --additional-columns x\
        --additional-columns y\
        --additional-columns z\
        --additional-columns qv\
        --additional-columns overlaps_nucleus\
        --additional-columns gene\
        --outfile transcripts.csv

    """
}

workflow {
  transcripts = Channel.fromPath( params.transcripts )\
  | tileXenium \
  | flatten \
  | filter{ it.size()>0 } \
  | Baysor \
  | collect \
  | mergeTiles
}
