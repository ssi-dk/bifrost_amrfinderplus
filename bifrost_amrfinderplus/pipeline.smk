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
from snakemake.io import directory
import datetime

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

if not samplecomponent.has_requirements():
   common.set_status_and_save(sample, samplecomponent, "Requirements not met")
   raise SystemExit("Requirements not met")


onerror:
    if not samplecomponent.has_requirements():
        common.set_status_and_save(sample, samplecomponent, "Requirements not met")
    if samplecomponent["status"] == "Running":
        common.set_status_and_save(sample, samplecomponent, "Failure")

envvars:
    "BIFROST_INSTALL_DIR",
    "CONDA_PREFIX",
    "BIFROST_CPUS_BIG",

JOB_CPUS = int(os.environ.get("BIFROST_CPUS_BIG", 4))

resources_dir = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}"

# -------------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------------

rule all:
    input:
        f"{component['name']}/datadump_complete"
    run:
        common.set_status_and_save(sample, samplecomponent, "Success")

rule set_time_start:
    output:
        start_file = f"{component['name']}/time_start.txt"
    run:
        import time
        with open(output.start_file, "w") as fh:
            fh.write(str(time.time()))

rule setup:
    input:
        rules.set_time_start.output.start_file
    output:
        init_file = touch(f"{component['name']}/initialized")
    run:
        samplecomponent["path"] = os.path.join(os.getcwd(), component["name"])
        samplecomponent.save()

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
    genus = species.split()[0]

    amr_opts = component["options"]["amrfinderplus_organism_option"]
    # config_file = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}/bifrost_{component['display_name']}/config.yaml"
    # with open(config_file, "r") as f:
    #     config_yaml = yaml.safe_load(f)

    #amr_opts = config_yaml["options"]["amrfinderplus_organism_option"]

    organism_option = None
    for key, value in amr_opts.items():
        if key.lower().startswith(genus.lower()):
            organism_option = value
            break

    if organism_option is None:
        print(f"Genus '{genus}' not found. Using 'Other'.")
        organism_option = amr_opts["Other"]

    print(f"AMRFinderPlus organism option: {organism_option}")
    return organism_option


species = determine_species(sample, component)
organism_option = map_species_to_amrfinder(species, component)

rule_name = "run_amrfinderplus"
rule run_amrfinderplus:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log"
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        contigs = sample["categories"]["contigs"]["summary"]["data"]
    output:
        amr_report = f"{component['name']}/{component['name']}_amr_report.txt",
        mut_report = f"{component['name']}/{component['name']}_mutation_report.txt",
        tool_version = f"{component['name']}/tool_version.txt"
    params:
        org = organism_option,
        amrfinder_db = f"{os.environ['BIFROST_INSTALL_DIR']}{component['resources']['amrfinderplus_db']}/latest",
        sample_name = sample["name"]
    threads: JOB_CPUS
    shell:
        r"""
        amrfinder \
            --nucleotide {input.contigs} \
            --organism {params.org} \
            --database {params.amrfinder_db} \
            --name {params.sample_name} \
            --mutation_all {output.mut_report} \
            --threads {threads} \
            --plus \
            --print_node \
            --report_all_equal \
            --output {output.amr_report} \
            1> {log.out_file} 2> {log.err_file}

        amrfinder --version > {output.tool_version} 2>&1
        """

#* Dynamic section: end ****************************************************************************

# -------------------------------------------------------------------------
# END TIME + RUNTIME (FILE-BASED)
# -------------------------------------------------------------------------

rule set_time_end:
    input:
        rules.run_amrfinderplus.output.amr_report
    output:
        end_file = f"{component['name']}/time_end.txt"
    run:
        import time
        with open(output.end_file, "w") as fh:
            fh.write(str(time.time()))


rule_name = "git_version"
rule git_version:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        rules.setup.output.init_file
    output:
        git_hash = f"{component['name']}/git_hash.txt"
    run:
        import subprocess, os

        snake_dir = os.path.dirname(workflow.snakefile)

        try:
            git_hash = subprocess.check_output(
                ["git", "-C", snake_dir, "rev-parse", "HEAD"],
                stderr=subprocess.STDOUT,
                text=True
            ).strip()
        except Exception as e:
            git_hash = "-"
            os.makedirs(os.path.dirname(log.err_file), exist_ok=True)
            with open(log.err_file, "a") as fh:
                fh.write(f"[git_version] Could not determine git hash from {snake_dir}: {e}\n")

        with open(output.git_hash, "w") as fh:
            fh.write(str(git_hash))

rule dump_info:
    input:
        start_file = rules.set_time_start.output.start_file,
        end_file = rules.set_time_end.output.end_file,
        tool_version = rules.run_amrfinderplus.output.tool_version,
        git_hash = rules.git_version.output.git_hash
    output:
        runtime_flag = touch(f"{component['name']}/runtime_set")
    run:
        import time
        from bifrostlib.datahandling import SampleComponent

        with open(input.start_file) as fh:
            t_start = float(fh.read().strip())
        with open(input.end_file) as fh:
            t_end = float(fh.read().strip())
        with open(input.tool_version) as fh:
            tool_version = str(fh.read().rstrip("\n"))
        with open(input.git_hash) as fh:
            git_hash = str(fh.read().strip())

        runtime_minutes = (t_end - t_start) / 60.0
        print(f"runtime in minutes {runtime_minutes}")

        sc = SampleComponent.load(samplecomponent.to_reference())
        sc["time_start"] = datetime.datetime.fromtimestamp(t_start).strftime("%Y-%m-%d %H:%M:%S")
        sc["time_end"] = datetime.datetime.fromtimestamp(t_end).strftime("%Y-%m-%d %H:%M:%S")
        sc["time_running"] = round(runtime_minutes, 3)
        sc["tool_version"] = tool_version
        sc["git_hash"] = git_hash

        sc.save()

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
        amr_report_file = rules.run_amrfinderplus.output.amr_report,
        mutation_report_file = rules.run_amrfinderplus.output.mut_report,
        runtime_flag = rules.dump_info.output.runtime_flag	
    output:
        complete = f"{component['name']}/datadump_complete"
    params:
        samplecomponent_id = samplecomponent["_id"]
    script:
        os.path.join(os.path.dirname(workflow.snakefile), "datadump.py")

#- Templated section: end --------------------------------------------------------------------------