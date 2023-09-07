# Xenium segmentation

A nextflow pipeline for segmentation of 10x Xenium runs. The pipeline consists of the following parts:

- Create a nuclear segmentation using the DAPI maximal intensity projection using a trained cellpose model. In our experience, this works slightly better that the nuclear segmentation that Xenium is running internally. See the [nuclear_segmentation.ipynb](https://github.com/maximilian-heeg/xenium-segmentation/blob/main/scripts/nuclear_segmentation.ipynb) notebook. Cellpose and all dependencies are wrapped in a [docker image](https://github.com/maximilian-heeg/docker-cellpose).
- Assign transcripts to nucleus (or unassigned if not within a nucleus). 
- Filter the transcripts based on OV values, remove non-gene transcripts and create smaller tiles of the dataset. For more information see [tile-xenium](https://github.com/maximilian-heeg/tile-xenium).
- Run Baysor on all tiles. This step uses [Baysor](https://github.com/kharchenkolab/Baysor) wrapped in a [docker image](https://github.com/maximilian-heeg/baysor-container).
- Merge the segmentation results to get one final segmentation. This [program](https://github.com/maximilian-heeg/merge-baysor) merges cells based on an IOU threshold.

![Diagram showing the pipeline](diagram.drawio.png)


## Usage

The pipeline requires a working installation of [nextflow](https://www.nextflow.io/). Further, it uses [singularity/apptainer](https://apptainer.org/) to run the scripts in reproducible environments.
Run the pipeline with:

    nextflow run maximilian-heeg/xenium-segmentaion -r v0.1.0 --xenium_path PATH_TO_XENIUM_OUTOUT

### Parameters

Many parameters can be manually set (and might need to be adjusted for best reuslts.)

    /*********************************
    Input and Output. 
    *********************************/ 
    // The folder pointing towards the xenium results
    xenium_path = null
        // Path to where the final csv should be saved.
    outdir = 'results'
    
    /*********************************
    Tile creation
    *********************************/
    // The width of a tile
    tile.width = 4000 
    // The height of a tile
    tile.height = 4000
    // The overlap between titles. The next tile with start at x + width - overlap, or y + height - overlap
    tile.overlap = 200
    // The minimum Q-Score to pass filtering. 
    tile.qv = 20
    // The minimum number of transcripts per tile. This is important
    // because baysor cannot work, if there are too few transcripts.
    // If the minimal number is not met in a tile, it will be expanded by `overlap` 
    // in all fofur directions until the criterion is met.
    tile.minimal_transcripts = 10000


    /*********************************
    Baysor
    *********************************/
    // Minimal number of molecules for a cell to be considered as
    // real. It's an important parameter, as it's used to infer
    // several other parameters. Overrides the config value.
    baysor.min_molecules_per_cell = 30

    // Standard deviation of scale across cells. Can be either
    // number, which means absolute value of the std, or string
    // ended with '%' to set it relative to scale (default: "25%")
    // Negative values mean it must be estimated from `min_molecules_per_cell`
    baysor.scale = -1.0

    // Confidence of the prior_segmentation results.
    // Value in [0; 1]. If you want the final segmentation not
    // contradicting to prior_segmentation, set it to 1.
    // Otherwise, if you assume errors in prior_segmentation,
    // values in [0.2-0.7] allow flexibility for the algorithm.
    baysor.prior_segmentation_confidence = 0.5

    /*********************************
    Merging
    *********************************/
    // Threshold for stitching. If the IOU for two cells is greater than the threshold, they will be merged
    merge.iou_threshold = 0.2


These parameters can either be changed by adding the parameters to the command (`--baysor.min_molecules_per_cell 60`) or by creating a `nextflow.config` file within the working directory.

<pre>
// Change the min_molecules_per_cell for Baysor
params {
    baysor.min_molecules_per_cell = <strong>60</strong>
}
</pre>

### Executors

> In the Nextflow framework architecture, the executor is the component that determines the system where a pipeline process is run and supervises its execution.
> 
> The executor provides an abstraction between the pipeline processes and the underlying execution system. This allows you to write the pipeline functional logic independently from the actual processing platform.
> 
> In other words, you can write your pipeline script once and have it running on your computer, a cluster resource manager, or the cloud — simply change the executor definition in the Nextflow configuration file.

Again, you can set an executor by modifying the `nextflow.config`.

<pre>
// Use the PBS scheduler
process {
    executor = 'pbs'
    queue = 'home-yeo'
}
</pre>