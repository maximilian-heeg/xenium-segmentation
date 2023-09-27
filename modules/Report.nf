

process dumpParameters {
  output:
    path "parameter.md"

  """
  cat > parameter.md << EOF
  # Parameters

  ## Input / Output
  - xenium_path: $params.xenium_path
  - outdir: $params.outdir

  ## Tile creation
  - width: $params.tile.width
  - height: $params.tile.height
  - overlap: $params.tile.overlap
  - minimal_transcripts: $params.tile.minimal_transcripts

  ## Baysor
  - min_molecules_per_cell: $params.baysor.min_molecules_per_cell
  - min_molecules_per_cell_fraction: $params.baysor.min_molecules_per_cell_fraction
  - min_molecules_per_segment: $params.baysor.min_molecules_per_segment
  - scale: $params.baysor.scale
  - scale_std: $params.baysor.scale_std
  - n_clusters: $params.baysor.n_clusters
  - prior_segmentation_confidence: $params.baysor.prior_segmentation_confidence
  - nuclei_genes: $params.baysor.nuclei_genes
  - cyto_genes: $params.baysor.cyto_genes
  - new_component_weight: $params.baysor.new_component_weight

  ## Merging
  - merge_threshold: $params.merge.iou_threshold

  ## Report
  -  report.width = $params.report.width
  -  report.height = $params.report.height
  -  report.x_offset = $params.report.x_offset
  -  report.y_offset = $params.report.y_offset
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

    echo "# Baysor config \n\n" > baysor_config.md
    sed -e 's/^/     /' baysor.toml >> baysor_config.md

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