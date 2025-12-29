#!/bin/bash

last_run=$(nextflow log -q | tail -n 1)
nextflow clean -before $last_run -f
