#!/bin/bash

# Script to update retailer_voucher table in PostgreSQL database
# This will update the expiry date for approved but unredeemed vouchers

echo "Updating retailer_voucher table expiry dates..."

# Run the SQL command in the postgres container
docker exec -i ryo_postgres psql -U jagoan2025 -d mkt_ryo << EOF
UPDATE retailer_voucher
SET expired_at='2025-07-31 23:59:59+00'
WHERE is_approved=TRUE
AND redeemed=FALSE;
EOF

# Check if the command was successful
if [ $? -eq 0 ]; then
    echo "Successfully updated retailer_voucher table"
    echo "All approved and unredeemed vouchers now expire on July 31, 2025"
else
    echo "Error updating retailer_voucher table"
fi
