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

try:
    sample_ref = SampleReference(_id=config.get('sample_id', None), name=config.get('sample_name', None))
    sample:Sample = Sample.load(sample_ref)  # schema 2.1
    sample_id = sample['name']
    species_detection = sample.get_category("species_detection")
    species = species_detection["summary"].get("species", None)
    species_sp = species.split()[0]
    if sample is None:
        print("Sample is None!")	   
        raise Exception("invalid sample passed")
    
    component_ref = ComponentReference(name=config['component_name'])
    component:Component = Component.load(reference=component_ref)  # schema 2.1
    if component is None:
        raise Exception("invalid component passed")

    samplecomponent_ref = SampleComponentReference(name=SampleComponentReference.name_generator(sample.to_reference(), component.to_reference()))
    samplecomponent = SampleComponent.load(samplecomponent_ref)								            

    if samplecomponent is None:
        print(f"Creating new sample component: {samplecomponent_ref}")
        samplecomponent = SampleComponent(sample_reference=sample.to_reference(), component_reference=component.to_reference())  # schema 2.1
    
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

envvars:
    "BIFROST_INSTALL_DIR",
    "CONDA_PREFIX"

resources_dir = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}"

# Modify the 'all' rule to depend only on the 'check_requirements' rule
rule all:
    input:
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

rule_name = "check_requirements"
rule check_requirements:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        folder = rules.setup.output.init_file,
    output:
        check_file = directory(f"{component['name']}/requirements_met"),
    params:
        samplecomponent
    run:
        requirements_met_dir = output.check_file
        if not os.path.exists(requirements_met_dir):
            os.makedirs(requirements_met_dir)
        if samplecomponent.has_requirements():
            with open(output.check_file, "w") as fh:
                fh.write("")

rule_name = "run_amrfinderplus_on_assembly"
rule run_amrfinderplus_on_assembly:
    message:
        f"Running step: run_amrfinderplus_on_assembly"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        rules.check_requirements.output.check_file,
        assembly = f"{assemblatron_path}/{sample_id}.fasta",
    output:
        amr_report = f"{component['name']}/{component['name']}_amr_report.txt",
        mut_report = f"{component['name']}/{component['name']}_mutation_report.txt",
    params:
        threads = 1,
        id = 0.9,
        cov = 0.6,
        org = species_sp,
        sample_id = sample_id,
    shell:
        """
        amrfinder --nucleotide {input.assembly} --organism {params.org} --name {params.sample_id} --mutation_all {output.mut_report} --plus --print_node --report_all_equal --output {output.amr_report} 1> {log.out_file} 2> {log.err_file}
        """

#* Dynamic section: end ****************************************************************************

#- Templated section: start ------------------------------------------------------------------------
rule_name = "datadump"
rule datadump:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        amr_report_file = rules.run_amrfinderplus_on_assembly.output.amr_report,
        mutation_report_file = rules.run_amrfinderplus_on_assembly.output.mut_report,
    output:
        complete = rules.all.input
    params:
        samplecomponent_ref_json = samplecomponent.to_reference().json
    script:
        f"{resources_dir}/bifrost_amrfinderplus/datadump.py"
#- Templated section: end --------------------------------------------------------------------------