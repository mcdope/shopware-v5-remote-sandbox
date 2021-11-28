# shopware-v5-remote-sandbox
A remote sandbox for Shopware v5, based on Dockware and same basic shell magic

# Usage
- Copy `.env.dist` to `.env`, adjust the contained variables to your needs
   - you can skip the STORE_ variables, but then Pickware won't be auto-installed
- You can place plugins conforming to the "new" plugin system, first introduced in 
  Shopware 5.2, in `data/plugins_new_system`. Plugins for the old plugin system can
  be place in `data/plugins_old_system`. They will be auto-installed then.
- Customers, Addresses and Orders for testing can be auto-imported
   - For customers: do a SwagImportExport export, save it as `customers.xml` in `data`
   - For addresses: do a SwagImportExport export, save it as `addresses.xml` in `data`
   - For orders: SwagImportExport can't properly create orders, so this is XML based. 
     Dump needs to be place in `data` as `sw-test-orders.sql`. Following tables should
     be contained: `s_core_payment_data`, `s_core_payment_instance`, `s_order`, `s_order_attributes`, 
     `s_order_billingaddress`, `s_order_details`, `s_order_details_attributes`, `s_order_esd`, 
     `s_order_history`, `s_order_notes`, `s_order_number`, `s_order_shippingaddress`, 
     `s_order_shippingaddress_attributes`
- start sandbox by running `./start.sh`
- create a reverse proxy host, see `docker-composer.yml` for ports

# Note

This is mainly for myself, expect quirks etc. 

