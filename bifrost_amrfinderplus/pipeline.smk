#- Templated section: start ------------------------------------------------------------------------
import os
import sys
import traceback

from bifrostlib import common
from bifrostlib.datahandling import SampleReference
from bifrostlib.datahandling import Sample
from bifrostlib.datahandling import ComponentReference
from bifrostlib.datahandling import Component
from bifrostlib.datahandling import SampleComponentReference
from bifrostlib.datahandling import SampleComponent
os.umask(0o2)

# To get the species from what's my species component.
sample = Sample.load(samplecomponent.sample)
species_detection = sample.get_category("species_detection")
species = species_detection["summary"].get("species", None)
# Code to run
if species not in component["options"]["mlst_species_mapping"]:
    run_cmd(f"touch {component['name']}/no_mlst_species_DB")
else:
    species = component["options"]["mlst_species_mapping"][species]

try:
    sample_ref = SampleReference(_id=config.get('sample_id', None), name=config.get('sample_name', None))
    sample:Sample = Sample.load(sample_ref) # schema 2.1
    if sample is None:
        raise Exception("invalid sample passed")

    component_ref = ComponentReference(name=config['component_name'])
    component:Component = Component.load(reference=component_ref) # schema 2.1
    if component is None:
        raise Exception("invalid component passed") # component needs to be in database
    samplecomponent_ref = SampleComponentReference(name=SampleComponentReference.name_generator(sample.to_reference(), component.to_reference()))
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    if samplecomponent is None:
        samplecomponent:SampleComponent = SampleComponent(sample_reference=sample.to_reference(), component_reference=component.to_reference()) # schema 2.1
    common.set_status_and_save(sample, samplecomponent, "Running")

    # This gets the nucleotide fasta from assemblatron.
    assemblatron_samplecomponent_field = [i for i in sample['components'] if i['name'].startswith('assemblatron')] 
    # there may be multiple components associated with the sample, so we select the most recent one.
    most_recent_assemblatron_name = sorted([i['name'] for i in assemblatron_samplecomponent_field], reverse=True)[0]
    assemblatron_reference = ComponentReference(name=most_recent_assemblatron_name)
    assemblatron_samplecomponent_ref = SampleComponentReference(name=SampleComponentReference.name_generator(sample.to_reference(), assemblatron_reference))
    assemblatron_samplecomponent = SampleComponent.load(assemblatron_samplecomponent_ref)
    assemblatron_path = assemblatron_samplecomponent['path']
except Exception as error:
    print(traceback.format_exc(), file=sys.stderr)
    raise Exception("failed to set sample, component and/or samplecomponent")

onerror:
    if not samplecomponent.has_requirements():
        common.set_status_and_save(sample, samplecomponent, "Requirements not met")
    if samplecomponent['status'] == "Running":
        common.set_status_and_save(sample, samplecomponent, "Failure")

rule all:
    input:
        # file is defined by datadump function
        f"{component['name']}/datadump_complete"
    run:
        common.set_status_and_save(sample, samplecomponent, "Success")

rule setup:
    output:
        init_file = touch(temp(f"{component['name']}/initialized")),
    params:
        folder = component['name']
    run:
        samplecomponent['path'] = os.path.join(os.getcwd(), component['name'])
        samplecomponent.save()

rule check_requirements:
    message:
        f"Running step: check_requirements"
    log:
        out_file = f"{component['name']}/log/check_requirements.out.log",
        err_file = f"{component['name']}/log/check_requirements.err.log",
    benchmark:
        f"{component['name']}/benchmarks/check_requirements.benchmark"
    input:
        folder = rules.setup.output.init_file,
    output:
        check_file = f"{component['name']}/requirements_met",
    run:
        if samplecomponent.has_requirements():
            print('opening requirements for components')
            with open(output.check_file, "w") as fh:
                fh.write("")

#- Templated section: end --------------------------------------------------------------------------

#* Dynamic section: start **************************************************************************

rule run_amrfinderplus_on_reads:
    message:
        f"Running step: run_amrfinderplus_on_reads"
    log:
        out_file = f"{component['name']}/log/run_amrfinderplus_on_reads.out.log",
        err_file = f"{component['name']}/log/run_amrfinderplus_on_reads.err.log",
    benchmark:
        f"{component['name']}/benchmarks/run_amrfinderplus_on_reads.benchmark"
    input:
        rules.check_requirements.output.check_file,
        #reads = sample['categories']['paired_reads']['summary']['data']
        genome = os.path.join(assemblatron_path, "contigs.fasta")
    output:
        #amrfinderplus_results = directory(f"{component['name']}/amrfinderplus_results"),
        amr_report = f"{component['name']}/{component['name']}_amr_report.tsv",
        mut_report = f"{component['name']}/{component['name']}_mutation_report.tsv",
    params:
        amrfinderplus_db = component['resources']['amrfinderplus_db']
        threads = 4
        id = 0.9
        cov = 0.6
        org = species
        id_name = sample.name
    shell:
        "amrfinder --nucleotide {input.genome} --name {params.id_name} --database {params.amrfinderplus_db} --threads {params.threads} --plus --ident_min {params.id} --coverage_min {params.cov} --organism {params.org} --output {output.amr_report} --mutation_all {output.mut_report}"
