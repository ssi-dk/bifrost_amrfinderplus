from bifrostlib import common
from bifrostlib.datahandling import (Category, Component, Sample,
                                     SampleComponent, SampleComponentReference)
from typing import Dict
import os
import csv

# Function to parse TSV file into a list of dictionaries
def parse_tsv(file_name: str) -> list:
    results = []
    with open(file_name, mode='r') as file:
        reader = csv.DictReader(file, delimiter='\t')
        for row in reader:
            results.append(row)
    return results

# Function to extract results from the TSV and load them into the serotype category
def extract_results_from_tsv(AMRfinder_category: Category, results: Dict, file_name: str, category_type: str) -> None:
    if category_type == "amr_report":
        # Process AMR Report data
        amr_results = parse_tsv(file_name)
        AMRfinder_category["summary"]["amr"] = amr_results
    elif category_type == "mutation_report":
        # Process Mutation Report data
        mutation_results = parse_tsv(file_name)
        AMRfinder_category["summary"]["mutation"] = mutation_results

# Main function to handle the datadump
def datadump(input: object, output: object, samplecomponent_ref_json: Dict):
    samplecomponent_ref = SampleComponentReference(value=samplecomponent_ref_json)
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    sample = Sample.load(samplecomponent.sample)
    
    # Get the serotype category or create a new one
    AMRfinder_category = sample.get_category("AMRfinder_category")
    if AMRfinder_category is None:
        AMRfinder_category = Category(value={
            "name": "bifrost_amrfinder",
            "component": {"id": samplecomponent["component"]["_id"], "name": samplecomponent["component"]["name"]},
            "summary": {
                "amr": [],
                "mutation": [],
            },
            "report": {}
        })

    # Assuming the input provides paths to amr_report.tsv and mutation_report.tsv
    extract_results_from_tsv(
        AMRfinder_category,
        samplecomponent["results"],
        input.amr_report_file,
        category_type="amr_report"
    )
    
    extract_results_from_tsv(
        AMRfinder_category,
        samplecomponent["results"],
        input.mutation_report_file,
        category_type="mutation_report"
    )

       # Save the results in the sample and samplecomponent
    samplecomponent.set_category(AMRfinder_category)
    sample.set_category(AMRfinder_category)
    samplecomponent.save_files()
    common.set_status_and_save(sample, samplecomponent, "Success")
    
    # Mark the completion of the datadump step
    print(output.complete)
    with open(output.complete[0], "w+") as fh:
        fh.write("done")

# Assuming `input` has mutation_report and amr_report, `output` has complete, and `params` provides the reference JSON
datadump(
    snakemake.input,
    snakemake.output,
    snakemake.params.samplecomponent_ref_json,
)
