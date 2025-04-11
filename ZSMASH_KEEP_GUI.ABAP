report  zsmash_keep_gui.

data: t_file type standard table of localfile.
append 'test' to t_file.
data: w_string_file type string.
w_string_file =  'C:\temp\123.txt'.

do.
   call function 'GUI_DOWNLOAD'
     exporting
       filename = w_string_file
     tables
       data_tab = t_file
     exceptions
       others   = 22.
   if sy-subrc <> 0.
   endif.

   call function 'GUI_UPLOAD'
     exporting
       filename = w_string_file
     tables
       data_tab = t_file
     exceptions
       others   = 17.
   if sy-subrc <> 0.
   endif.
enddo. 
