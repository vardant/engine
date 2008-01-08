      subroutine gep_physics(abort,err)

      implicit none
      save

      character*11 here
      parameter(here='gep_physics')

      logical abort
      character*(*) err

      include 'gen_run_info.cmn'
      include 'gen_event_info.cmn'
      include 'gen_data_structures.cmn'
      include 'hms_data_structures.cmn'
      include 'hms_scin_parms.cmn'
      include 'bigcal_data_structures.cmn'
      include 'gep_data_structures.cmn'
      include 'gen_constants.par'
      include 'hms_scin_tof.cmn'
      include 'hms_physics_sing.cmn'
      include 'bigcal_tof_parms.cmn'
      include 'bigcal_gain_parms.cmn'
      include 'bigcal_shower_parms.cmn'
      include 'bigcal_geometry.cmn'
      include 'bigcal_bypass_switches.cmn'
c
c     local variables:
c

c     FIRST PART OF THIS CODE IS TO USE HMS INFO TO SELECT BEST TRACK IN BIGCAL!!!
c     HMS phi is centered at -PI/2, therefore, we need to rotate bigcal phi so
c     that it is centered at +PI/2
c     here we want to use the HMS singles physics info to choose the best track
c     from BigCal assuming elastic kinematics!!!
      integer pick_best_cal_track

c      logical fixed_bigcal

      real etheta_expect,ephi_expect
      real exhat,eyhat,ezhat,exhat_tar,eyhat_tar,ezhat_tar
      real xint_hexpect,yint_hexpect,zint_hexpect
      real xcal_hexpect
      real ycal_hexpect
      real Ecal_hexpect
      real tcal_hexpect
      real Eprime,ethetarad,ephirad,Q2,nu
      real pthetarad,pphirad
      real vx,vy,vz
      real etint
      real edx,edy,edz,ethetacorr,ephicorr,epathlength,mom_corr
      real gamma_corr,beta_corr,tof
      real Q2_cal,Q2_hms,Q2_htheta,nu_htheta,pp_htheta,pp_btheta
      real nu_btheta
      real Ee_btheta 
      real hoffset_ctime,boffset_ctime,htrigt,btrigt,mindiff

      real Mp
      parameter(Mp=.938272)
      
      real Me

      integer i,ibest_cal

      real PI
      parameter(PI=3.14159265359)

c     if the user has not defined something reasonable, then set by hand here:
      
      if(GEP_sigma_Ediff.lt..001.or.GEP_sigma_Ediff.gt.10.0) then
         GEP_sigma_Ediff = .06
      endif
      if(GEP_sigma_Xdiff.lt..001.or.GEP_sigma_Xdiff.gt.100.0) then
         GEP_sigma_Xdiff = 1.0
      endif
      if(GEP_sigma_Ydiff.lt..001.or.GEP_sigma_Ydiff.gt.100.0) then
         GEP_sigma_Ydiff  =1.0
      endif
      if(GEP_sigma_Tdiff.lt..001.or.GEP_sigma_Tdiff.gt.1000.0) then
         GEP_sigma_Tdiff = 10.0
      endif

      if(gen_bigcal_mc.eq.3) then ! fill HMS info from Monte Carlo:
         hsnum_fptrack = 1
         hsp = pp_mc
         hsdelta = (hsp - hpcentral)/hpcentral
         hsenergy = sqrt(hsp**2 + Mp**2)
         hstheta = ptheta_mc*PI/180.
         hsphi = (- pphi_mc - 90.)*PI/180.
         hszbeam = zv_p_mc
         gbeam_x = xv_p_mc
         gbeam_y = yv_p_mc
      endif

      if(hsnum_fptrack.le.0) then
         return
      endif

c     here we compute the expected cluster time in BigCal (using the focal-plane time for the 
c     good track):

      hoffset_ctime = hstime_at_fp - hstart_time_center + hspath_cor ! should be around zero for most

      mindiff = 0.

      if(ntrigb.gt.0) then
         do i=1,ntrigb
            if(i.eq.1.or.abs(gep_btime(i)-gep_btime_elastic).lt.mindiff) then
               btrigt = gep_btime(i)
               mindiff = abs(gep_btime(i)-gep_btime_elastic)
            endif
         enddo
      else
         btrigt = gep_btime_elastic
      endif

c     invert (common-stop) hms trigger times using the same user parameter as for BigCal:

      if(ntrigh2.gt.0.and.ntrigh1.eq.0) then 
         htrigt = bigcal_end_time - gep_h2time(1)
      else if(ntrigh1.gt.0.and.ntrigh2.eq.0) then
         htrigt = bigcal_end_time - gep_h1time(1)
      else if(ntrigh1.gt.0.and.ntrigh2.gt.0) then ! use trig. time 2
         htrigt = bigcal_end_time - gep_h2time(1)
      else ! shouldn't hardcode coin. trigger delay, but most data is taken with 
c     16 ns delay of HMS trigger relative to BigCal trigger. Eventually set up a user param.
         htrigt = bigcal_end_time - gep_btime_elastic + gep_htrig_delay
      endif
      
c     here are the possible scenarios for the coincidence trigger: 
c     1. BigCal comes in first by about 16 ns (or gep_htrig_delay). This is most likely for good 
c     elastics, but
c     the timing resolution of BigCal is comparatively poor (several ns as opposed to sub-ns 
c     in the case of the hms scintillators), and the tail of the BigCal trigger time peak has some
c     overlap with the HMS self-timing peak.
c     2. the BigCal trigger comes in later than the HMS trigger, and the ADC gate/TDC stop comes 
c     from the BigCal self-timing peak. 
c     Now, suppose we have a good elastic event for which the hms trigger self-times and picks out
c     a track with focal-plane time near hstart_time_center (normal case). Then, we should look for
c     BigCal clusters coming in 16 ns (gep_htrig_delay) earlier than htrig + hoffset_ctime! 
c     Now, suppose we have a good elastic event for which the bigcal trigger self-times and the HMS
c     trigger comes in earlier. IF BigCal self-times, then we also expect the good cluster time to be
c     in the self-timing peak for BigCal, and an earlier HMS time. But essentially, we should always 
c     look for the BigCal cluster 16 ns before the HMS focal-plane time, because that is where our 
c     elastics are:

      tcal_hexpect = htrigt + hoffset_ctime - gep_htrig_delay
c      tcal_hexpect = hoffset_ctime

c$$$      write(*,*) 'tcal_hexpect=',tcal_hexpect
c$$$      write(*,*) 'hoffset_ctime=',hoffset_ctime
c$$$      write(*,*) 'htrigt=',htrigt

      Me = mass_electron ! convenient shorthand

c     calculate nu for elastic-ep:

      nu = sqrt(Mp**2 + hsp**2) - Mp

c     expected electron energy:
      Eprime = gebeam - nu

      Ecal_hexpect = Eprime

      pthetarad = hstheta
      pphirad = hsphi - 3.*PI/2.

c     calculate proton momentum (assuming elastic) from hstheta:

      Q2_htheta = 4.*Mp**2*gebeam**2*(cos(hstheta))**2 / 
     $     (Mp**2 + 2.*Mp*gebeam + gebeam**2*(sin(hstheta))**2)
      nu_htheta = Q2_htheta / (2.*Mp)

      pp_htheta = sqrt(nu_htheta**2 + 2.*Mp*nu_htheta)

c     calculate electron angle from gebeam and hsp only, since the resolution of these quantities is better than 
c     you can get using hstheta, the reason being the large Jacobian of the reaction. The error on etheta is
c     magnified roughly by a factor hsp/Eprime compared to the error on hstheta, and this in turn gives a 
c     large error on xcal,ycal

      if(nu.ge.gebeam) then ! this is certainly not an elastic proton!!!!   
         Eprime = 0.
         etheta_expect = 0.
         xcal_hexpect = -999.
         ycal_hexpect = -999.
         goto 173
c     set Eprime and theta to zero and skip calculation of expected electron position:
      else if(nu/Eprime.gt.2.*gebeam/Mp) then ! ep elastic is still kinematically forbidden!
         Eprime = 0.
         etheta_expect = 0.
         xcal_hexpect = -999.
         ycal_hexpect = -999.
         goto 173
      else ! if ep-elastic is not explicitly kinematically forbidden, then
c     use elastic kinematics to predict the electron position and energy:
c     since we have yet to put a cut on the correlation between hsp and pel(hstheta), 
c     we won't always get a sensible value. Just want to prevent annoying divide-by-zero messages for now.
         etheta_expect = acos(1. - Mp/gebeam * nu / Eprime)
      endif
         
      ! in BigCal coordinates, phi is centered at 0 for BigCal. In target coordinates, BigCal is 
      ! centered at +PI/2, while HMS is centered at -PI/2. However, since BigCal y means -target x
      ! we have to be careful. 

      if(pphirad.gt.0) then 
         pphirad = pphirad - PI
      endif
      
      ephi_expect = pphirad + PI

      ethetarad = etheta_expect 

      gep_etheta_expect_H = ethetarad
      gep_ephi_expect_H = ephi_expect
     
c     first calculate exhat,eyhat,ezhat in target coordinates so there is no ambiguity: 
      
      exhat_tar = sin(ethetarad)*cos(ephi_expect)
      eyhat_tar = sin(ethetarad)*sin(ephi_expect)
      ezhat_tar = cos(ethetarad)

c     now rotate to BigCal coordinates:
      
      exhat = eyhat_tar
      eyhat = -exhat_tar
      ezhat = ezhat_tar

      !write(*,*) 'exhat,eyhat,ezhat=',exhat,eyhat,ezhat

c     vertex coordinates expressed in BigCal coordinate system
c     turns out that beam x and y coordinates are the same as BigCal coordinates

      vz = hszbeam ! along beamline
      vx = gbeam_x ! horizontal toward BigCal
      vy = gbeam_y ! vertical up (target x is vertical down.)

      !write(*,*) 'vertex xyz=',vx,vy,vz

c     etint is the trajectory parameter, calculated at the intersection point with the face of BigCal,
c     in other words, if e- position = vertex + et*ehat, where ehat is the unit trajectory vector and et is 
c     the parameter determining where we are on the line, then etint is the value of the parameter when the 
c     electron hits the calorimeter. 
c     so we are calculating the intersection point of the e- trajectory expected from the HMS with BigCal:

      etint = (bigcal_r_tgt-vx*bigcal_sintheta-vz*bigcal_costheta) / 
     $     (exhat * bigcal_sintheta + ezhat*bigcal_costheta)

      xint_hexpect = vx + etint * exhat
      yint_hexpect = vy + etint * eyhat
      zint_hexpect = vz + etint * ezhat

      !write(*,*) 'xint,yint,zint=',xint_hexpect,yint_hexpect,zint_hexpect

c     now rotate into calo-centered coordinate system:

      xcal_hexpect=xint_hexpect*bigcal_costheta-zint_hexpect*bigcal_sintheta
      ycal_hexpect=yint_hexpect
c      tcal_hexpect= hstime_at_fp - hstart_time_center + hspath_cor

c     for now, just take time difference relative to bigcal_window center
c      tcal_hexpect = bigcal_window_center
      
      if(gen_bigcal_mc.eq.3) then
         tcal_hexpect = 0.0
      endif

 173  continue

      gep_bx_expect_H = xcal_hexpect
      gep_by_expect_H = ycal_hexpect

      !write(*,*) 'bigcal e_hms,x_hms,y_hms=',Eprime,xcal_hexpect,ycal_hexpect

c     how to choose? pick the track for which the quadrature sum of 
c     sum( ((Eclust-Eexpect)/sigma)**2 + ((xclust-xexpect)/sigma)**2 + ((yclust-yexpect)/sigma)**2 ) is minimum
c     the resolution parameters sigma should be CTP parms

      if(b_use_bad_chan_list.ne.0) then
c     check bigcal clusters, and, if necessary, fix clusters near the 
c     expected electron position containing channels in the "bad" list

c         fixed_bigcal = .false.
*     fixed_bigcal will be true if any channels from the bad channel list are 
*     filled with a guess and if any cluster is rebuilt or a new cluster is found
         call gep_check_bigcal(gep_bx_expect_H,gep_by_expect_H,Eprime)
      endif

      call b_calc_physics(abort,err) ! reconstruct physics quantities for BigCal. 
c     this routine should only get called once per event!!!!!!!!!!!!!!!!

*     now pick up where we left off:


      ibest_cal = pick_best_cal_track(tcal_hexpect,gep_etheta_expect_h,
     $     gep_ephi_expect_h,gep_bx_expect_h,gep_by_expect_h,Ecal_hexpect)

      


c     now compute "missing" quantities using the track we have selected.
c     first correct best calo track for vertex information which we now know from HMS reconstruction:

      if(ibest_cal.eq.0) return

      bigcal_itrack_best = ibest_cal

c     correct angles since we know vertex:
      
      edx = bigcal_track_xface(ibest_cal) - vx
      edy = bigcal_track_yface(ibest_cal) - vy
      edz = bigcal_track_zface(ibest_cal) - vz

      epathlength = sqrt(edx**2 + edy**2 + edz**2)

      bigcal_thetarad = acos(edz/epathlength)
      bigcal_phirad = atan2(edy,edx)
      
      bigcal_track_thetarad(ibest_cal) = bigcal_thetarad
      bigcal_track_phirad(ibest_cal) = bigcal_phirad

      bigcal_energy = bigcal_track_energy(ibest_cal)
      
c     correct tof:
      
      gamma_corr = bigcal_energy / Me

c     could get a "NaN" error here: check:
      if(gamma_corr.lt.1.) gamma_corr = 1.

      beta_corr = sqrt(max(0.,1.-1./gamma_corr**2))

      if(beta_corr.eq.0.) beta_corr = 1.
      bigcal_beta = beta_corr
      bigcal_tof = epathlength / (beta_corr*speed_of_light)
      
      mom_corr = beta_corr * bigcal_energy

      bigcal_px = mom_corr * sin(bigcal_thetarad) * cos(bigcal_phirad)
      bigcal_py = mom_corr * sin(bigcal_thetarad) * sin(bigcal_phirad)
      bigcal_pz = mom_corr * cos(bigcal_thetarad)

      bigcal_eloss = bigcal_track_eloss(ibest_cal)
      bigcal_time = bigcal_track_time(ibest_cal)
      bigcal_tof_cor = bigcal_tof - bigcal_tof_central
      bigcal_ctime = bigcal_track_time(ibest_cal) - bigcal_tof_cor - 
     $     (bigcal_end_time - gep_btime_elastic)

      gep_ctime_hms = hstime_at_fp - hstart_time_center + hspath_cor
      gep_ctime_cal = bigcal_ctime

      if(gen_bigcal_mc.eq.3) then 
         gep_ctime_hms = 0.
         gep_ctime_cal = 0.
      endif

      Ee_btheta = gebeam / (1. + gebeam/Mp * (1. - cos(bigcal_thetarad)))

      nu_btheta = gebeam - Ee_btheta
      pp_btheta = sqrt(nu_btheta**2 + 2.*Mp*nu_btheta)
c     compute Q2 three different ways:
c     Q2_Cal uses only BigCal information except for hms vertex info
c     Q2_hms uses only HMS information, period.
      Q2_cal = 2.*gebeam*Ee_btheta*(1.-cos(bigcal_thetarad))
      Q2_hms = 2.*Mp*nu
c     what is the average Q2? Both measurements are very good, except for bigcal_energy
c     best is probably to use Eprime calculated from hsp, but use BigCal angle measurement
c     corrected for HMS vertex info. Q2 from Ebeam, hsp alone (Q2_hms) may be even better than this. 
      GEP_Q2 = 2.*gebeam*Eprime*(1.-cos(bigcal_thetarad))
c     GEP_Q2 = .5*(Q2_cal + Q2_hms)
      GEP_Q2_H = Q2_hms
      GEP_Q2_B = Q2_cal
      GEP_E_electron = Eprime ! electron energy from HMS
      GEP_P_proton = hsp
      GEP_Pel_htheta = pp_htheta
      GEP_Pel_btheta = pp_btheta
      GEP_delta_p = hsdelta
      GEP_xfp_p = HSX_FP
      GEP_yfp_p = HSY_FP
      GEP_xpfp_p = HSXP_FP
      GEP_ypfp_p = HSYP_FP
      GEP_xptar_p = HSXP_TAR
      GEP_yptar_p = HSYP_TAR
      GEP_ytar_p = HSY_TAR
      GEP_epsilon = 1./(1.+2.*(1.+GEP_Q2/(4.*Mp**2))*(tan(bigcal_thetarad/2.))**2)
      GEP_etheta_deg = bigcal_thetarad * 180./PI
      GEP_ptheta_deg = hstheta * 180./PI
      GEP_ephi_deg = bigcal_phirad * 180./PI + 90.
      GEP_pphi_deg = pphirad * 180./PI

      GEP_Emiss = gebeam + Mp - hsenergy - bigcal_energy
      GEP_Pmissx = -bigcal_py + hsp*sin(hstheta)*cos(pphirad)
      GEP_Pmissy = bigcal_px + hsp*sin(hstheta)*sin(pphirad)
      GEP_Pmissz = gpbeam - bigcal_pz - hsp*cos(hstheta)
      GEP_Pmiss = sqrt(GEP_Pmissx**2 + GEP_Pmissy**2 + GEP_Pmissz**2)
      GEP_W2 = Mp**2 + Q2_hms - Q2_cal ! 2Mnu - Q2_cal
      GEP_Mmiss = sqrt(abs(GEP_W2 - Mp**2))

      return 
      end


      integer function pick_best_cal_track(T_H,TH_H,PH_H,X_H,Y_H,E_H)
      
      include 'gep_data_structures.cmn'
      include 'bigcal_data_structures.cmn'

      logical restore_E
      integer itrack,ibest
      real diffsum,mindiffsum

      real E_cal,TH_cal,PH_cal,T_cal,X_cal,Y_cal
      real T_H,TH_H,PH_H,E_H,X_H,Y_H

      real PI
      parameter(PI=3.14159265359)


      restore_E = .false.

      if(bigcal_phys_ntrack.gt.0) then
         do itrack = 1,bigcal_phys_ntrack
            E_cal = bigcal_track_energy(itrack)

            if(E_cal .gt. 10.0) then ! divide by 1000
               E_cal = E_cal / 1000.
               restore_E = .true.
            endif
            
            TH_cal = bigcal_track_thetarad(itrack)
            PH_cal = bigcal_track_phirad(itrack) + PI/2.


            T_cal = bigcal_track_time(itrack) - bigcal_track_tof_cor(itrack) -
     $(bigcal_end_time - gep_btime_elastic)
            X_cal = bigcal_all_clstr_x(itrack)
            Y_cal = bigcal_all_clstr_y(itrack)

            diffsum = 0.
            diffsum = diffsum + ( (E_cal - E_H)/GEP_sigma_Ediff )**2
            diffsum = diffsum + ( (TH_cal - TH_H)/GEP_sigma_thdiff )**2
            diffsum = diffsum + ( (PH_cal - PH_H)/GEP_sigma_phdiff )**2
            diffsum = diffsum + ( (T_cal - T_H)/GEP_sigma_Tdiff )**2
            diffsum = diffsum + ( (X_cal - X_H)/GEP_sigma_Xdiff )**2
            diffsum = diffsum + ( (Y_cal - Y_H)/GEP_sigma_Ydiff )**2

            if(itrack.eq.1) then
               mindiffsum = diffsum
               ibest = itrack
            else
               if(diffsum.lt.mindiffsum) then
                  mindiffsum = diffsum
                  ibest = itrack
               endif
            endif

            bigcal_all_clstr_chi2(itrack) = diffsum/6.
            bigcal_all_clstr_chi2contr(itrack,1) = ( (E_cal - E_H)/GEP_sigma_Ediff )**2
            bigcal_all_clstr_chi2contr(itrack,2) = ( (TH_cal - TH_H)/GEP_sigma_thdiff )**2
            bigcal_all_clstr_chi2contr(itrack,3) = ( (PH_cal - PH_H)/GEP_sigma_phdiff )**2
            bigcal_all_clstr_chi2contr(itrack,4) = ( (X_cal - X_H)/GEP_sigma_xdiff )**2
            bigcal_all_clstr_chi2contr(itrack,5) = ( (Y_cal - Y_H)/GEP_sigma_ydiff )**2
            bigcal_all_clstr_chi2contr(itrack,6) = ( (T_cal - T_H)/GEP_sigma_Tdiff )**2
            
            if(restore_E) E_cal = E_cal * 1000.

         enddo
         pick_best_cal_track = ibest
      else
         pick_best_cal_track = 0
      endif
      
      end
