# Makefile

.PHONY: test

clean:	
	rm -rf test/*txt &&\
	rm -rf test/bifrost_test_data*

# Combined test target to run all steps - processing amrfinder
test: testdata amrfinder_db_update amrfinder md5amrcheck

testdata:
# Suppress the command output but allow the echo to print when directory exists
	@if [ ! -d "test/bifrost_test_data" ]; then \
		cd test && git clone https://github.com/ssi-dk/bifrost_test_data > /dev/null 2>&1; \
	else \
		echo "Directory test/bifrost_test_data already exists, skipping git clone."; \
	fi

amrfinder_db_update:
	amrfinder -u

# Step 1: Run the typing process
amrfinder:
	amrfinder --nucleotide test/bifrost_test_data/samples/SRR2094561.fasta --organism Salmonella --name SRR2094561 --mutation_all test/SRR2094561_mut_salmonella.txt --plus --print_node --report_all_equal -o test/SRR2094561_amr_salmonella.txt

# Step 2: Check MD5 checksum
md5amrcheck:
	cd test && \
	md5sum -c AMRfinder.md5
 