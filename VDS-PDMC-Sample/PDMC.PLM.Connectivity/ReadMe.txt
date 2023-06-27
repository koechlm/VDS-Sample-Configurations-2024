Follow these steps to activate the PDMC.PLM connectivity

1. Install powerJobs and powerPLM from coolOrange.com
2. Copy the subfolders powerJobs and powerEvents to the coolOrange program data folder C:\ProgramData\coolOrange\
	The folders exist but there is no risk to overwrite existing files. Merge the copy with them.

If you downloaded PDMC-Sample 2024.1 you are all set. If you migrated a legacy PDMC-Sample Vault, e.g. PDMC-Sample 2023 complete the setup with step 3 and following.

3. Open Vault Explorer -> Tools -> powerFLC Configuration Manager...
	3.1 Import the workflow Adsk.PDMC.PLM.Sample.ChangeTaskECO from C:\ProgramData\coolOrange\powerJobs\Jobs\Adsk.PDMC.PLM.Sample.ChangeTaskECO.json
	3.2 Import the workflow Adsk.PDMC.PLM.Sample.UploadItem from C:\ProgramData\coolOrange\powerJobs\Jobs\Adsk.PDMC.PLM.Sample.UploadItem.json
	3.3 Save and close the configuration manager
4. Create a new folder $/Designs/PLM.CO.Attachments