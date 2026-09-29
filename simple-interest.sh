#!/bin/bash

echo "Enter the principal amount:"
read p

echo "Enter the time period in years:"
read t

echo "Enter the annual rate of interest:"
read r

simple_interest=$(awk "BEGIN {print $p * $t * $r}")

echo "Simple Interest = $simple_interest"
