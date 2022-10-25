# from bifrostlib import common
# from bifrostlib.datahandling import Sample
# from bifrostlib.datahandling import SampleComponentReference
# from bifrostlib.datahandling import SampleComponent
# from bifrostlib.datahandling import Category
# from typing import Dict
# import os
# import json

# def extract_resistance(resistance: Category, results: Dict, component_name: str) -> None:
#     file_name = "amrfinderplus_results/output.tsv"
#     # file_key = common.json_key_cleaner(file_name)
#     # file_path = os.path.join(component_name, file_name)
#     # with open(file_path) as input:
#     #     results_json = json.load(input)
#     # results[file_key]={}
#     # for gene in results_json['genes'].keys():
    #     gene_obj = results_json['genes'][gene]
    #     gene_dict={}
    #     gene_dict['gene'] = gene_obj['name']
    #     gene_dict['phenotype'] = ", ".join(gene_obj['phenotypes'])
    #     gene_dict['point mutation'] = None # todo
    #     resistance['summary']['genes'].append(gene_dict)
    #     report_dict = {}
    #     report_dict['gene'] = gene_obj['name']
    #     report_dict['coverage'] = gene_obj['coverage']
    #     report_dict['identity'] = gene_obj['identity']
    #     report_dict['variants'] = None # todo
    #     #print(resistance['summary'])
    #     resistance['report']['data'].append(report_dict)
    # results[file_key]['genes'] = resistance['summary']['genes']


# def datadump(samplecomponent_ref_json: Dict):
#     samplecomponent_ref = SampleComponentReference(value=samplecomponent_ref_json)
#     samplecomponent = SampleComponent.load(samplecomponent_ref)
#     sample = Sample.load(samplecomponent.sample)
#     resistance= samplecomponent.get_category("resistance")
#     if resistance is None:
#         resistance = Category(value={
#                 "name": "resistance",
#                 "component": {"id": samplecomponent["component"]["_id"], "name": samplecomponent["component"]["name"]},
#                 "summary": {"genes":[]},
#                 "report": {"data":[]}
#             }
#         )
#     extract_resistance(resistance, samplecomponent["results"], samplecomponent["component"]["name"])
#     samplecomponent.set_category(resistance)
#     sample.set_category(resistance)
#     common.set_status_and_save(sample, samplecomponent, "Success")
    
#     with open(os.path.join(samplecomponent["component"]["name"], "datadump_complete"), "w+") as fh:
#         fh.write("done")

# datadump(
#     snakemake.params.samplecomponent_ref_json,
# )
