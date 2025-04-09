process runInstanseg {
    container 'docker://maximilianheeg/instanseg:v0.0.8'
    cpus 8
    memory { 20.GB * task.attempt }
    time { 4.hour * task.attempt }
    errorStrategy 'retry'
    maxRetries 3
    containerOptions '--contain -B /tmp:/tmp --env INSTANSEG_BIOIMAGEIO_PATH=/tmp/ --nv'
    input:
        path 'xenium'
        path 'script.py'
    output:
        path 'instanseg_nuclei_mask.npy', emit: nuclei_mask
        path 'instanseg_cell_mask.npy', emit: cell_mask

    """
        python script.py xenium
    """
}


process runXeniumRanger {
    container 'docker://maximilianheeg/xeniumranger:v3.1.0'
    cpus 16
    memory { 40.GB * task.attempt }
    time { 4.hour * task.attempt }
    errorStrategy 'retry'
    maxRetries 3

    input:
        path "xenium_output"
        path "nuclei_mask.npy"
        path "cell_mask.npy"

    output:
        path "xenium-instanseg/outs/*"

    publishDir "$params.outdir",
        mode: 'copy',
        overwrite: true,
        saveAs: { filename ->
            def relativePath = filename.toString() - "xenium-instanseg/outs/"
            return "${relativePath}"
        }

    """
    xeniumranger import-segmentation\
         --id=xenium-instanseg \
         --xenium-bundle=xenium_output \
         --cells=cell_mask.npy \
         --localcores=16

    """
}

workflow Instanseg {
    take:
        ch_xenium_output

    main:

        ch_instanseg = runInstanseg(
            ch_xenium_output,
            Channel.fromPath("$baseDir/scripts/run_instanseg.py"),
        )

        runXeniumRanger(
            ch_xenium_output,
            ch_instanseg.nuclei_mask,
            ch_instanseg.cell_mask,
        )

}
