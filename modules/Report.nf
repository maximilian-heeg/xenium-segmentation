import groovy.json.JsonOutput

process dumpParameters {
  output:
    path "parameter.md"

  
  script:
    json_str = JsonOutput.toJson(params)
    json_indented = JsonOutput.prettyPrint(json_str)
    """
    cat > parameter.md << EOF
# Parameters

\\`\\`\\`json
  ${json_indented}
\\`\\`\\`
EOF
    """
}


process diagnostics {
  container 'docker://maximilianheeg/docker-scanpy:v1.9.5'
  cpus 8
  memory { 20.GB * task.attempt }
  time { 4.hour * task.attempt }
  errorStrategy 'retry'
  maxRetries 3
  input:
    path 'notebook.ipynb'
    path 'data/xenium'
    path "data/transcripts.csv"
    path "data/transcripts_cellpose.csv"
  output:
    path 'notebook.nbconvert.ipynb'
  

  """
    jupyter nbconvert --to notebook --execute notebook.ipynb
  """
}

process evaluation {
  container 'docker://maximilianheeg/docker-scanpy:v1.9.5'
  cpus 8
  memory { 20.GB * task.attempt }
  time { 4.hour * task.attempt }
  errorStrategy 'retry'
  maxRetries 3
  input:
    path 'notebook.ipynb'
    path "data/transcripts.csv"
    path "data/transcripts_cellpose.csv"
  output:
    path 'notebook.nbconvert.ipynb'
  

  """
    jupyter nbconvert --to notebook --execute notebook.ipynb
  """
}

process scanpy {
  container 'docker://maximilianheeg/docker-scanpy:v1.9.5'
  publishDir "$params.outdir", mode: 'copy', overwrite: true,  pattern: '*.h5ad'
  cpus 8
  memory { 20.GB * task.attempt }
  time { 4.hour * task.attempt }
  errorStrategy 'retry'
  maxRetries 3
  input:
    path 'notebook.ipynb'
    path 'data/xenium'
    path "data/transcripts.csv"
  output:
    path 'notebook.nbconvert.ipynb', emit: notebook
    path 'anndata.h5ad'
  

  """
    export WIDTH=$params.report.width
    export HEIGHT=$params.report.height
    export X_OFFSET=$params.report.x_offset
    export Y_OFFSET=$params.report.y_offset
    jupyter nbconvert --to notebook --execute notebook.ipynb
  """
}

process boundaries {
  container 'docker://maximilianheeg/docker-scanpy:v1.9.5'
  cpus 8
  memory { 20.GB * task.attempt }
  time { 4.hour * task.attempt }
  errorStrategy 'retry'
  maxRetries 3
  input:
    path 'notebook.ipynb'
    path 'data/xenium'
    path "data/transcripts.csv"
    path "data/transcripts_cellpose.csv"
  output:
    path 'notebook.nbconvert.ipynb'
  

  """
    export WIDTH=$params.report.width
    export HEIGHT=$params.report.height
    export X_OFFSET=$params.report.x_offset
    export Y_OFFSET=$params.report.y_offset
    jupyter nbconvert --to notebook --execute notebook.ipynb
  """
}

process build {
  container 'docker://maximilianheeg/docker-scanpy:v1.9.5'
  input:
    path 'parameter.md'
    path 'segmentation.ipynb'
    path "baysor.toml"
    path 'diagnostics.ipynb'
    path 'evaluation.ipynb'
    path 'scanpy.ipynb'
    path 'boundaries.ipynb'
  output:
    path 'report/*'
  publishDir "$params.outdir", mode: 'copy', overwrite: true

  """
    cp -r $baseDir/scripts/report/*  .

    echo "# Baysor config \n\n\\`\\`\\`toml" > baysor_config.md
    cat baysor.toml >> baysor_config.md
    echo "\\`\\`\\`" >> baysor_config.md
    
    jupyter-book build .
    mkdir report
    cp -r _build/html/* report/
  """
}


workflow Report {
    take:
        ch_xenium_output
        ch_baysor_segmentation
        ch_nuclear_segmentation
        ch_nuclear_segmentation_notebook
        ch_baysor_config
    main:

        ch_parameter = dumpParameters()

        ch_diagnostics = diagnostics(
            Channel.fromPath("$baseDir/scripts/diagnostics.ipynb"),
            ch_xenium_output,
            ch_baysor_segmentation,
            ch_nuclear_segmentation
        )

        ch_evaluation = evaluation(
            Channel.fromPath("$baseDir/scripts/evaluation.ipynb"),
            ch_baysor_segmentation,
            ch_nuclear_segmentation
        )

        ch_scanpy = scanpy(
            Channel.fromPath("$baseDir/scripts/scanpy.ipynb"),
            ch_xenium_output,
            ch_baysor_segmentation
        )

        ch_boundaries = boundaries(
            Channel.fromPath("$baseDir/scripts/boundaries.ipynb"),
            ch_xenium_output,
            ch_baysor_segmentation,
            ch_nuclear_segmentation
        )

        build(
            ch_parameter,
            ch_nuclear_segmentation_notebook,
            ch_baysor_config,
            ch_diagnostics,
            ch_evaluation,
            ch_scanpy.notebook,
            ch_boundaries
        )
}