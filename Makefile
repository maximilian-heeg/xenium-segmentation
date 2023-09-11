clean: 
	rm -rf .nextflow*
	rm -rf work
	rm -rf results

test:
	nextflow run main.nf \
		-resume \
		--xenium_path data \
		--tile.width 600 \
		--baysor.min_molecules_per_cell 100 \
		--outdir results/test
		
test2:
	nextflow run main.nf \
		-resume \
		--xenium_path data \
		--tile.width 600 \
		--baysor.prior_segmentation_confidence 1\
		--baysor.min_molecules_per_cell 100 \
		--outdir results/test

test3:
	nextflow run main.nf \
		-resume \
		--xenium_path data \
		--tile.width 600 \
		--baysor.prior_segmentation_confidence 1\
		--baysor.scale_std 50%\
		--baysor.min_molecules_per_cell 100 \
		--outdir results/test

test4:
	nextflow run main.nf \
		-resume \
		--xenium_path data \
		--tile.width 600 \
		--baysor.prior_segmentation_confidence 1\
		--baysor.scale_std 80%\
		--baysor.min_molecules_per_cell 100 \
		--outdir results/test

cleantest: clean test

all: test test2 test3 test4