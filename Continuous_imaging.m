
%% Get data from ActiChamp and reconstruct
Acti.Close();
imagePeriod = 0.25; %How often to image in seconds
drawnow
% How much data to collect for each image

R = Reconstruct;
set(R.hReconFig,'Toolbar','figure')
plot3(R.axRecon,mesh_simple(1:200:end,1),mesh_simple(1:200:end,2),mesh_simple(1:200:end,3),'LineStyle','none',...
    'Marker','x','MarkerEdgeColor','red')
hold(R.axRecon)

h=plot3(R.axRecon,mesh_simple(:,1),mesh_simple(:,2),mesh_simple(:,3),'LineStyle','none','Marker','o')

XThreshold = get(R.sliderThreshold,'Value');
set(R.sliderThreshold,'Value',1);



%%
for i = 1:100 %while(1)
    tic
    
    %%
     Acti.Go(imagePeriod);
     
     Data  = Acti.data_buf';

    Pert = get_BV_Acti(Data,Acti,Filt,Freqs,Prt);
    dV = Pert(prt_good) - Baseline(prt_good);
    
X = Tik.predict(dV);

% Update interpolation function with new values, and update plot.
% F_interp.V = X;
% A = F_interp(Xg,Yg);
% %      A(abs(A)<12) = 0;
% %      A(abs(A)>=12) = 1;
% set(h,'CData',abs(A))



XMax = max(abs(X));
XMin = min(abs(X));
XThreshold = get(R.sliderThreshold,'Value')


set(R.textReconMax,'String',XMax);
set(R.textReconMin,'String',XMin);
set(R.sliderThreshold,'Value',min(XThreshold,XMax));
set(R.textThreshold,'String',XThreshold);
set(R.sliderThreshold,'Max',XMax);
set(R.sliderThreshold,'Min',XMin);


A = mesh_simple(:,3);
A(X<XThreshold)=NaN;
set(h,'ZData',A);
drawnow
 %%
   
end

%%
