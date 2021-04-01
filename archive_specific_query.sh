#!/bin/bash

RESC_NAME="tier_1"

iadmin asq "select distinct d.data_owner_name, c.coll_name, d.data_name, r.resc_name, data_meta.meta_attr_value::real
from     r_data_main d,
         r_resc_main r,
         r_coll_main c,
         r_objt_metamap resc_metamap1,
         r_objt_metamap resc_metamap3,
         r_objt_metamap data_metamap,
         r_meta_main resc_meta1,
         r_meta_main resc_meta3,
         r_meta_main data_meta
where    d.resc_id = r.resc_id and
         d.coll_id = c.coll_id and
         r.resc_id = resc_metamap1.object_id and
         r.resc_id = resc_metamap3.object_id and
         resc_metamap1.meta_id = resc_meta1.meta_id and
         resc_metamap3.meta_id = resc_meta3.meta_id and
         d.data_id                 = data_metamap.object_id and
         data_metamap.meta_id      = data_meta.meta_id and
         resc_meta1.meta_attr_name = 'irods::resource::filesystem_percent_used' and
         resc_meta3.meta_attr_name = 'irods::resource::threshold_percent'       and
         data_meta.meta_attr_name  = 'irods::access_time'                       and
         resc_meta1.meta_attr_value::real > resc_meta3.meta_attr_value::real    and
         r.resc_name = '${RESC_NAME}'
order by data_meta.meta_attr_value::real asc
        " ${RESC_NAME}_archive_query
