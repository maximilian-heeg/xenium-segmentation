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
  container 'docker://maximilianheeg/docker-scanpy:v1.9.5_pyarrow'
  cpus 8
  memory { 20.GB * task.attempt }
  time { 4.hour * task.attempt }
  errorStrategy 'retry'
  maxRetries 3
  input:
    path 'notebook.ipynb'
    path 'data/xenium'
    path "data/transcripts.csv"
    path "data/transcripts_xenium.parquet"
  output:
    path 'notebook.nbconvert.ipynb'
  

  """
    jupyter nbconvert --to notebook --execute notebook.ipynb
  """
}

process build {
  container 'docker://maximilianheeg/docker-scanpy:v1.9.5_pyarrow'
  input:
    path 'parameter.md'
    path "baysor.toml"
    path 'diagnostics.ipynb'
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
        ch_xenium_segmentation
        ch_baysor_config
    main:

        ch_parameter = dumpParameters()

        ch_diagnostics = diagnostics(
            Channel.fromPath("$baseDir/scripts/diagnostics.ipynb"),
            ch_xenium_output,
            ch_baysor_segmentation,
            ch_xenium_segmentation
        )

        build(
            ch_parameter,
            ch_baysor_config,
            ch_diagnostics,
        )
}