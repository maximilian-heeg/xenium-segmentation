.PHONY: clean test download

EXAMPLE_URL = https://cf.10xgenomics.com/samples/xenium/3.0.0/Xenium_Prime_MultiCellSeg_Mouse_Ileum_tiny/Xenium_Prime_MultiCellSeg_Mouse_Ileum_tiny_outs.zip
EXAMPLE_DIR = test/example
RESULT_DIR = test/result

download:
	mkdir -p $(EXAMPLE_DIR)
	# rm -rf $(EXAMPLE_DIR)/*
	wget $(EXAMPLE_URL) -O $(EXAMPLE_DIR)/example.zip
	unzip -o $(EXAMPLE_DIR)/example.zip -d $(EXAMPLE_DIR)
	rm $(EXAMPLE_DIR)/example.zip

clean:
	rm -rf .nextflow*
	rm -rf work
	rm -rf test

test_baysor: download
	export NXF_SINGULARITY_HOME_MOUNT=true && \
	export NXF_SINGULARITY_CACHEDIR=singularity && \
	nextflow run main.nf \
	-resume \
	--xenium_path $(EXAMPLE_DIR) \
	--baysor.min_molecules_per_cell -1 \
	--baysor.prior_segmentation_confidence 0.9 \
	--tile.minimal_transcripts 500 \
	--xeniumranger.alpha 0.0 \
	--outdir $(RESULT_DIR)_baysor


test_instanseg: download
	export NXF_SINGULARITY_HOME_MOUNT=true && \
	export NXF_SINGULARITY_CACHEDIR=singularity && \
	nextflow run main.nf \
	-resume \
	--segmentation_method instanseg \
	--xenium_path $(EXAMPLE_DIR) \
	--outdir $(RESULT_DIR)_instanseg

test_all: test_baysor test_instanseg
