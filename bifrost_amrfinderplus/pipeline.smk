#- Templated section: start ------------------------------------------------------------------------
import os
import sys
import traceback
import yaml

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
    sample: Sample = Sample.load(sample_ref)
    if sample is None:
        raise Exception("invalid sample passed")

    component_ref = ComponentReference(name=config['component_name'])
    component: Component = Component.load(reference=component_ref)
    if component is None:
        raise Exception("invalid component passed")

    samplecomponent_ref = SampleComponentReference(
        name=SampleComponentReference.name_generator(sample.to_reference(), component.to_reference())
    )
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    if samplecomponent is None:
        samplecomponent = SampleComponent(
            sample_reference=sample.to_reference(),
            component_reference=component.to_reference()
        )

    common.set_status_and_save(sample, samplecomponent, "Running")

except Exception:
    print(traceback.format_exc(), file=sys.stderr)
    raise Exception("failed to set sample, component and/or samplecomponent")

onerror:
    if not samplecomponent.has_requirements():
        common.set_status_and_save(sample, samplecomponent, "Requirements not met")
    if samplecomponent["status"] == "Running":
        common.set_status_and_save(sample, samplecomponent, "Failure")

envvars:
    "BIFROST_INSTALL_DIR",
    "CONDA_PREFIX"

resources_dir = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}"

# -------------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------------

rule all:
    input:
        f"{component['name']}/datadump_complete"
    run:
        common.set_status_and_save(sample, samplecomponent, "Success")

rule setup:
    output:
        init_file = touch(f"{component['name']}/initialized")
    run:
        samplecomponent["path"] = os.path.join(os.getcwd(), component["name"])
        samplecomponent.save()

rule_name = "check_requirements"
rule check_requirements:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log"
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        rules.setup.output.init_file
    output:
        check_file = touch(f"{component['name']}/requirements_met")
    run:
        if samplecomponent.has_requirements():
            pass

#* Dynamic section: start **************************************************************************

def determine_species(sample, component):
    sd = sample.get_category("species_detection")
    if sd is not None:
        species = sd["summary"].get("species")
    else:
        species = sample.get_category("sample_info")["summary"].get("provided_species")

    print(f"Detected species: {species}")
    return species


def map_species_to_amrfinder(species, component):
    species_sp = species.split()[0]

    config_file = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}/bifrost_{component['display_name']}/config.yaml"
    with open(config_file, "r") as f:
        config_yaml = yaml.safe_load(f)

    amr_opts = config_yaml["options"]["amrfinderplus_organism_option"]

    organism_option = None
    for key, value in amr_opts.items():
        if key.lower() == species_sp.lower():
            organism_option = value
            break

    if organism_option is None:
        print(f"Species '{species_sp}' not found. Using 'Other'.")
        organism_option = amr_opts["Other"]

    print(f"AMRFinderPlus organism option: {organism_option}")
    return organism_option


species = determine_species(sample, component)
organism_option = map_species_to_amrfinder(species, component)

rule_name = "run_amrfinderplus_on_assembly"
rule run_amrfinderplus_on_assembly:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log"
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        rules.check_requirements.output.check_file,
        assembly = sample["categories"]["contigs"]["summary"]["data"]
    output:
        amr_report = f"{component['name']}/{component['name']}_amr_report.txt",
        mut_report = f"{component['name']}/{component['name']}_mutation_report.txt"
    params:
        org = organism_option,
        amrfinder_db = f"{os.environ['BIFROST_INSTALL_DIR']}{component['resources']['amrfinderplus_db']}/latest",
        sample_name = sample["name"]
    shell:
        r"""
        amrfinder \
            --nucleotide {input.assembly} \
            --organism {params.org} \
            --database {params.amrfinder_db} \
            --name {params.sample_name} \
            --mutation_all {output.mut_report} \
            --plus \
            --print_node \
            --report_all_equal \
            --output {output.amr_report} \
            1> {log.out_file} 2> {log.err_file}
        """

#* Dynamic section: end ****************************************************************************

# -------------------------------------------------------------------------
# DATADUMP
# -------------------------------------------------------------------------

rule_name = "datadump"
rule datadump:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log"
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        amr_report_file = rules.run_amrfinderplus_on_assembly.output.amr_report,
        mutation_report_file = rules.run_amrfinderplus_on_assembly.output.mut_report
    output:
        complete = f"{component['name']}/datadump_complete"
    params:
        samplecomponent_ref_json = samplecomponent.to_reference().json
    script:
        f"{resources_dir}/bifrost_amrfinderplus/datadump.py"
#- Templated section: end --------------------------------------------------------------------------
