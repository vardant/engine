      subroutine sane_close_scalers()
      IMPLICIT NONE
      include 'b_ntuple.cmn'
      include 'bigcal_data_structures.cmn'
      include 'bigcal_tof_parms.cmn'
      include 'hms_data_structures.cmn'
      include 'bigcal_gain_parms.cmn'
      include 'gen_event_info.cmn'
      include 'gen_data_structures.cmn'
      include 'gep_data_structures.cmn'
      include 'sane_ntuple.cmn'
      include 'sane_data_structures.cmn'
      include 'sem_data_structures.cmn'
      INCLUDE 'h_ntuple.cmn'
      include 'f1trigger_data_structures.cmn'
      include 'hms_calorimeter.cmn'
      include 'gen_detectorids.par'
      include 'gen_scalers.cmn'
      include 'gen_run_info.cmn'

      if(.not.charge_data_open)then
         charge2s = gbcm1_charge-tcharge
         tcharge = gbcm1_charge
c         write(*,*)'MMM'
c      endif
c      if(.not.charge_data_open.and.gscaler_change(538).ne.hel_p_scaler)then
        hel_p_scaler= gscaler_change(538)
        hel_p_trig= g_hel_pos
        dtime_p =1.
        if(abs(g_hel_pos).gt.0)then
           dtime_p = gscaler_change(538)/float(g_hel_pos)
        endif
        call NANcheckF(dtime_p,0)
        g_hel_pos =0
c        write(*,*)'MMM P'
c      endif
c      if(.not.charge_data_open.and.gscaler_change(546).ne.hel_n_scaler)then
        hel_n_scaler= gscaler_change(546)
        hel_n_trig= g_hel_neg
        dtime_n=1
        if(abs(g_hel_neg).gt.0.0)then
           dtime_n = gscaler_change(546)/float(g_hel_neg)
        endif
        call NANcheckF(dtime_n,0)
        g_hel_neg =0
c        write(*,*)'MMM N'
      endif
      write(*,*)'Writing Last SCALER'
      if(.not.polarization_data_open)then
          write(polarization_data_unit,*)gen_event_ID_number,polarea, polarization,half_plate
          polarization_ch = .FALSE.
      endif

      if(.not.charge_data_open)then
         write(charge_data_unit,*)gen_event_ID_number,charge2s,tcharge,hel_p_scaler,
     ,        hel_p_trig,dtime_p,hel_n_scaler,hel_n_trig,dtime_n
         charge_ch = .FALSE.
      endif

      close(polarization_data_unit)
      close(charge_data_unit)


      end
