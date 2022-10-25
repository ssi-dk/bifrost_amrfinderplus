from setuptools import setup, find_packages

setup(
    name='bifrost_amrfinderplus',
    version='v1_0_0',
    url='https://github.com/ssi-dk/bifrost_amrfinderplus',

    # Author details
    author='Karen Loaiza',
    author_email='kloc@ssi.dk',

    # Choose your license
    license='MIT',

    packages=find_packages(),
    python_requires='>=3.6',

    package_data={'bifrost_amrfinderplus': ['config.yaml', 'pipeline.smk']},
    include_package_data=True,

    install_requires=[
        'bifrostlib >= 2.0.11'
    ]
)