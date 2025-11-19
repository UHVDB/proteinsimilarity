# CarsonJM/nf-proteinsimilarity: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.0 - [2025-11-14]

### `Added`

- New `CREATE_VIRUS_DB` process to build virus kmer-db once upfront instead of rebuilding for each PHIST process execution
- Added `process_super_high` resource label (24 CPUs, 96GB memory, 4h runtime) for high-performance compute requirements
- Added `maxForks` limit of 50 to ARIA2C process to prevent resource exhaustion

### `Changed`

- Optimized workflow by building virus kmer-db once and caching it using `storeDir` in `CREATE_VIRUS_DB` process
- Modified PHIST process to accept pre-built virus kmer-db file as input parameter instead of building it internally
- Refactored `phist.py` script to accept `virus_db` input parameter and removed internal kmer-db build logic
- Increased `process_high` memory allocation from 48GB to 96GB
- Default `--chunk_size` increased from 1,000 to 10,000
- Added `Usage` section to README

### `Fixed`

### `Dependencies`

### `Deprecated`


## v1.0.0 - [2025-11-11]

### `Added`

- Initial release of [nf-proteinsimilarity](https://github.com/CarsonJM/nf-proteinsimilarity)

### `Changed`

### `Fixed`

### `Dependencies`

| Tool       | Version used 
| ---------- | ----------- |
| aria2      | 1.36.0      |
| python     | 3.14.0      |
| kmer-db    | 2.3.1       |

### `Deprecated`
