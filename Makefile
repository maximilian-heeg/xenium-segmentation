clean: 
	rm -rf .nextflow*
	rm -rf work
	rm -rf results

test:
	nextflow run main.nf \
		-resume \
		--xenium_path data \
		--tile.width 600 \
		--baysor.min_molecules_per_cell -1 \
		--baysor.prior_segmentation_confidence 0.9\
		--outdir results/test
		
test2:
		nextflow run main.nf \
		-resume \
		--xenium_path data \
		--tile.width 600 \
		--baysor.min_molecules_per_cell -1 \
		--baysor.min_molecules_per_segment 0 \
		--baysor.prior_segmentation_confidence 0.9\
		--outdir results/test2


cleantest: clean test

all: test test2 