function [xtable ytable utable vtable typevector] = piv_FFTmulti (image1,image2,interrogationarea, step, subpixfinder, mask_inpt, roi_inpt,passes,int2,int3,int4,imdeform,repeat,mask_auto)
%profile on
%this funtion performs the  PIV analysis.
warning off %#ok<*WNOFF> %MATLAB:log:logOfZero
if numel(roi_inpt)>0
    xroi=roi_inpt(1);
    yroi=roi_inpt(2);
    widthroi=roi_inpt(3);
    heightroi=roi_inpt(4);
    image1_roi=double(image1(yroi:yroi+heightroi,xroi:xroi+widthroi));
    image2_roi=double(image2(yroi:yroi+heightroi,xroi:xroi+widthroi));
else
    xroi=0;
    yroi=0;
    image1_roi=double(image1);
    image2_roi=double(image2);
end
gen_image1_roi = image1_roi;
gen_image2_roi = image2_roi;

if numel(mask_inpt)>0
    cellmask=mask_inpt;
    mask=zeros(size(image1_roi));
    for i=1:size(cellmask,1);
        masklayerx=cellmask{i,1};
        masklayery=cellmask{i,2};
        mask = mask + poly2mask(masklayerx-xroi,masklayery-yroi,size(image1_roi,1),size(image1_roi,2)); %kleineres eingangsbild und maske geshiftet
    end
else
    mask=zeros(size(image1_roi));
end
mask(mask>1)=1;
gen_mask = mask;

miniy=1+(ceil(interrogationarea/2));
minix=1+(ceil(interrogationarea/2));
maxiy=step*(floor(size(image1_roi,1)/step))-(interrogationarea-1)+(ceil(interrogationarea/2)); %statt size deltax von ROI nehmen
maxix=step*(floor(size(image1_roi,2)/step))-(interrogationarea-1)+(ceil(interrogationarea/2));

numelementsy=floor((maxiy-miniy)/step+1);
numelementsx=floor((maxix-minix)/step+1);

LAy=miniy;
LAx=minix;
LUy=size(image1_roi,1)-maxiy;
LUx=size(image1_roi,2)-maxix;
shift4centery=round((LUy-LAy)/2);
shift4centerx=round((LUx-LAx)/2);
if shift4centery<0 %shift4center will be negative if in the unshifted case the left border is bigger than the right border. the vectormatrix is hence not centered on the image. the matrix cannot be shifted more towards the left border because then image2_crop would have a negative index. The only way to center the matrix would be to remove a column of vectors on the right side. but then we weould have less data....
    shift4centery=0;
end
if shift4centerx<0 %shift4center will be negative if in the unshifted case the left border is bigger than the right border. the vectormatrix is hence not centered on the image. the matrix cannot be shifted more towards the left border because then image2_crop would have a negative index. The only way to center the matrix would be to remove a column of vectors on the right side. but then we weould have less data....
    shift4centerx=0;
end
miniy=miniy+shift4centery;
minix=minix+shift4centerx;
maxix=maxix+shift4centerx;
maxiy=maxiy+shift4centery;

image1_roi=padarray(image1_roi,[ceil(interrogationarea/2) ceil(interrogationarea/2)], min(min(image1_roi)));
image2_roi=padarray(image2_roi,[ceil(interrogationarea/2) ceil(interrogationarea/2)], min(min(image1_roi)));
mask=padarray(mask,[ceil(interrogationarea/2) ceil(interrogationarea/2)],0);

if (rem(interrogationarea,2) == 0) %for the subpixel displacement measurement
    SubPixOffset=1;
else
    SubPixOffset=0.5;
end
xtable=zeros(numelementsy,numelementsx);
ytable=xtable;
utable=xtable;
vtable=xtable;
typevector=ones(numelementsy,numelementsx);

%% MAINLOOP
try %check if used from GUI
    handles=guihandles(getappdata(0,'hgui'));
    GUI_avail=1;
catch %#ok<CTCH>
    GUI_avail=0;
end

% divide images by small pictures
% new index for image1_roi and image2_roi


s0 = (repmat((miniy:step:maxiy)'-1, 1,numelementsx) + repmat(((minix:step:maxix)-1)*size(image1_roi, 1), numelementsy,1))';
s0 = permute(s0(:), [2 3 1]);
s1 = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
ss1 = repmat(s1, [1, 1, size(s0,3)])+repmat(s0, [interrogationarea, interrogationarea, 1]);

image1_cut = image1_roi(ss1);
image2_cut = image2_roi(ss1);
%do fft2

result_conv = fftshift(fftshift(real(ifft2(conj(fft2(image1_cut)).*fft2(image2_cut))), 1), 2);

%% repeated  Correlation 
%%{
if repeat == 1
    ms=round(step/4); %multishift parameter so groß wie viertel int window
    %Shift left bot
    s0B = (repmat((miniy+ms:step:maxiy+ms)'-1, 1,numelementsx) + repmat(((minix-ms:step:maxix-ms)-1)*size(image1_roi, 1), numelementsy,1))';
    s0B = permute(s0B(:), [2 3 1]);
    s1B = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
    ss1B = repmat(s1B, [1, 1, size(s0B,3)])+repmat(s0B, [interrogationarea, interrogationarea, 1]);
    image1_cutB = image1_roi(ss1B);
    image2_cutB = image2_roi(ss1B);
    result_convB = fftshift(fftshift(real(ifft2(conj(fft2(image1_cutB)).*fft2(image2_cutB))), 1), 2);
    
    %Shift right bot
    s0C = (repmat((miniy+ms:step:maxiy+ms)'-1, 1,numelementsx) + repmat(((minix+ms:step:maxix+ms)-1)*size(image1_roi, 1), numelementsy,1))';
    s0C = permute(s0C(:), [2 3 1]);
    s1C = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
    ss1C = repmat(s1C, [1, 1, size(s0C,3)])+repmat(s0C, [interrogationarea, interrogationarea, 1]);
    image1_cutC = image1_roi(ss1C);
    image2_cutC = image2_roi(ss1C);
    result_convC = fftshift(fftshift(real(ifft2(conj(fft2(image1_cutC)).*fft2(image2_cutC))), 1), 2);
    
    %Shift left top
    s0D = (repmat((miniy-ms:step:maxiy-ms)'-1, 1,numelementsx) + repmat(((minix-ms:step:maxix-ms)-1)*size(image1_roi, 1), numelementsy,1))';
    s0D = permute(s0D(:), [2 3 1]);
    s1D = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
    ss1D = repmat(s1D, [1, 1, size(s0D,3)])+repmat(s0D, [interrogationarea, interrogationarea, 1]);
    image1_cutD = image1_roi(ss1D);
    image2_cutD = image2_roi(ss1D);
    result_convD = fftshift(fftshift(real(ifft2(conj(fft2(image1_cutD)).*fft2(image2_cutD))), 1), 2);
    
    %Shift right top
    s0E = (repmat((miniy-ms:step:maxiy-ms)'-1, 1,numelementsx) + repmat(((minix+ms:step:maxix+ms)-1)*size(image1_roi, 1), numelementsy,1))';
    s0E = permute(s0E(:), [2 3 1]);
    s1E = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
    ss1E = repmat(s1E, [1, 1, size(s0E,3)])+repmat(s0E, [interrogationarea, interrogationarea, 1]);
    image1_cutE = image1_roi(ss1E);
    image2_cutE = image2_roi(ss1E);
    result_convE = fftshift(fftshift(real(ifft2(conj(fft2(image1_cutE)).*fft2(image2_cutE))), 1), 2);
    result_conv=result_conv.*result_convB.*result_convC.*result_convD.*result_convE;
    %%}
    
    %figure;imagesc(result_conv(:,:,100))
    %figure;imagesc(result_conv_multiplication(:,:,100))
    
    %{
figure;imagesc(result_conv(:,:,10));
figure;imagesc(result_convB(:,:,10));
figure;imagesc(result_convC(:,:,10));
figure;imagesc(result_convD(:,:,10));
figure;imagesc(result_convE(:,:,10));
    %}
    %%
end

if mask_auto == 1
    %das zentrum der Matrize (3x3) mit dem mittelwert ersetzen = Keine Autokorrelation
    %MARKER
    h = fspecial('gaussian', 3, 1.5);
    h=h/h(2,2);
    h=1-h;
    h=repmat(h,1,1,size(result_conv,3));
    h=h.*result_conv((interrogationarea/2)+SubPixOffset-1:(interrogationarea/2)+SubPixOffset+1,(interrogationarea/2)+SubPixOffset-1:(interrogationarea/2)+SubPixOffset+1,:);
    result_conv((interrogationarea/2)+SubPixOffset-1:(interrogationarea/2)+SubPixOffset+1,(interrogationarea/2)+SubPixOffset-1:(interrogationarea/2)+SubPixOffset+1,:)=h;
end


minres = permute(repmat(squeeze(min(min(result_conv))), [1, size(result_conv, 1), size(result_conv, 2)]), [2 3 1]);
deltares = permute(repmat(squeeze(max(max(result_conv))-min(min(result_conv))),[ 1, size(result_conv, 1), size(result_conv, 2)]), [2 3 1]);
result_conv = ((result_conv-minres)./deltares)*255;


%apply mask
ii = find(mask(ss1(round(interrogationarea/2+1), round(interrogationarea/2+1), :)));
jj = find(mask((miniy:step:maxiy)+round(interrogationarea/2), (minix:step:maxix)+round(interrogationarea/2)));
typevector(jj) = 0;
result_conv(:,:, ii) = 0;

[y, x, z] = ind2sub(size(result_conv), find(result_conv==255));

% we need only one peak from each couple pictures
[z1, zi] = sort(z);
dz1 = [z1(1); diff(z1)];
i0 = find(dz1~=0);
x1 = x(zi(i0));
y1 = y(zi(i0));
z1 = z(zi(i0));

xtable = repmat((minix:step:maxix)+interrogationarea/2, length(miniy:step:maxiy), 1);
ytable = repmat(((miniy:step:maxiy)+interrogationarea/2)', 1, length(minix:step:maxix));

if subpixfinder==1
    [vector] = SUBPIXGAUSS (result_conv,interrogationarea, x1, y1, z1, SubPixOffset);
elseif subpixfinder==2
    [vector] = SUBPIX2DGAUSS (result_conv,interrogationarea, x1, y1, z1, SubPixOffset);
end
vector = permute(reshape(vector, [size(xtable') 2]), [2 1 3]);

utable = vector(:,:,1);
vtable = vector(:,:,2);


%assignin('base','corr_results',corr_results);


%multipass
%feststellen wie viele passes
%wenn intarea=0 dann keinen pass.
for multipass=1:passes-1
    
    if GUI_avail==1
        set(handles.progress, 'string' , ['Frame progress: ' int2str(j/maxiy*100/passes+((multipass-1)*(100/passes))) '%' sprintf('\n') 'Validating velocity field']);drawnow;
    else
        fprintf('.');
    end
    %multipass validation, smoothing
    %stdev test
    utable_orig=utable;
    vtable_orig=vtable;
    stdthresh=4;
    meanu=nanmean(nanmean(utable));
    meanv=nanmean(nanmean(vtable));
    std2u=nanstd(reshape(utable,size(utable,1)*size(utable,2),1));
    std2v=nanstd(reshape(vtable,size(vtable,1)*size(vtable,2),1));
    minvalu=meanu-stdthresh*std2u;
    maxvalu=meanu+stdthresh*std2u;
    minvalv=meanv-stdthresh*std2v;
    maxvalv=meanv+stdthresh*std2v;
    utable(utable<minvalu)=NaN;
    utable(utable>maxvalu)=NaN;
    vtable(vtable<minvalv)=NaN;
    vtable(vtable>maxvalv)=NaN;
    
    %median test
    %info1=[];
    epsilon=0.02;
    thresh=2;
    [J,I]=size(utable);
    %medianres=zeros(J,I);
    normfluct=zeros(J,I,2);
    b=1;
    %eps=0.1;
    for c=1:2
        if c==1;
            velcomp=utable;
        else
            velcomp=vtable;
        end
        
        clear neigh
        for ii = -b:b;
            for jj = -b:b;
                neigh(:, :, ii+2*b, jj+2*b)=velcomp((1+b:end-b)+ii, (1+b:end-b)+jj);
            end
        end
        
        neighcol = reshape(neigh, size(neigh,1), size(neigh,2), (2*b+1)^2);
        neighcol2= neighcol(:,:, [(1:(2*b+1)*b+b) ((2*b+1)*b+b+2:(2*b+1)^2)]);
        neighcol2 = permute(neighcol2, [3, 1, 2]);
        med=median(neighcol2);
        velcomp = velcomp((1+b:end-b), (1+b:end-b));
        fluct=velcomp-permute(med, [2 3 1]);
        res=neighcol2-repmat(med, [(2*b+1)^2-1, 1,1]);
        medianres=permute(median(abs(res)), [2 3 1]);
        normfluct((1+b:end-b), (1+b:end-b), c)=abs(fluct./(medianres+epsilon));
    end
    
    
    info1=(sqrt(normfluct(:,:,1).^2+normfluct(:,:,2).^2)>thresh);
    utable(info1==1)=NaN;
    vtable(info1==1)=NaN;
    %find typevector...
    %maskedpoints=numel(find((typevector)==0));
    %amountnans=numel(find(isnan(utable)==1))-maskedpoints;
    %discarded=amountnans/(size(utable,1)*size(utable,2))*100;
    %disp(['Discarded: ' num2str(amountnans) ' vectors = ' num2str(discarded) ' %'])
    
    if GUI_avail==1
        if verLessThan('matlab','8.4')
            delete (findobj(getappdata(0,'hgui'),'type', 'hggroup'))
        else
            delete (findobj(getappdata(0,'hgui'),'type', 'quiver'))
        end
        hold on;
        vecscale=str2double(get(handles.vectorscale,'string'));
        %Problem: wenn colorbar an, zï¿½hlt das auch als aexes...
        colorbar('off')
        quiver ((findobj(getappdata(0,'hgui'),'type', 'axes')),xtable(isnan(utable)==0)+xroi-interrogationarea/2,ytable(isnan(utable)==0)+yroi-interrogationarea/2,utable_orig(isnan(utable)==0)*vecscale,vtable_orig(isnan(utable)==0)*vecscale,'Color', [0.15 0.7 0.15],'autoscale','off')
        quiver ((findobj(getappdata(0,'hgui'),'type', 'axes')),xtable(isnan(utable)==1)+xroi-interrogationarea/2,ytable(isnan(utable)==1)+yroi-interrogationarea/2,utable_orig(isnan(utable)==1)*vecscale,vtable_orig(isnan(utable)==1)*vecscale,'Color',[0.7 0.15 0.15], 'autoscale','off')
        drawnow
        hold off
    end
    
    %replace nans
    utable=inpaint_nans(utable,4);
    vtable=inpaint_nans(vtable,4);
    %smooth predictor
    try
        if multipass<passes-1
            utable = smoothn(utable,0.6); %stronger smoothing for first passes
            vtable = smoothn(vtable,0.6);
        else
            utable = smoothn(utable); %weaker smoothing for last pass
            vtable = smoothn(vtable);
        end
    catch
        
        %old matlab versions: gaussian kernel
        h=fspecial('gaussian',5,1);
        utable=imfilter(utable,h,'replicate');
        vtable=imfilter(vtable,h,'replicate');
    end
    
    if multipass==1
        interrogationarea=round(int2/2)*2;
    end
    if multipass==2
        interrogationarea=round(int3/2)*2;
    end
    if multipass==3
        interrogationarea=round(int4/2)*2;
    end
    step=interrogationarea/2;
    
    %bildkoordinaten neu errechnen:
    %roi=[];
    
    image1_roi = gen_image1_roi;
    image2_roi = gen_image2_roi;
    mask = gen_mask;
    
    
    miniy=1+(ceil(interrogationarea/2));
    minix=1+(ceil(interrogationarea/2));
    maxiy=step*(floor(size(image1_roi,1)/step))-(interrogationarea-1)+(ceil(interrogationarea/2)); %statt size deltax von ROI nehmen
    maxix=step*(floor(size(image1_roi,2)/step))-(interrogationarea-1)+(ceil(interrogationarea/2));
    
    numelementsy=floor((maxiy-miniy)/step+1);
    numelementsx=floor((maxix-minix)/step+1);
    
    LAy=miniy;
    LAx=minix;
    LUy=size(image1_roi,1)-maxiy;
    LUx=size(image1_roi,2)-maxix;
    shift4centery=round((LUy-LAy)/2);
    shift4centerx=round((LUx-LAx)/2);
    if shift4centery<0 %shift4center will be negative if in the unshifted case the left border is bigger than the right border. the vectormatrix is hence not centered on the image. the matrix cannot be shifted more towards the left border because then image2_crop would have a negative index. The only way to center the matrix would be to remove a column of vectors on the right side. but then we weould have less data....
        shift4centery=0;
    end
    if shift4centerx<0 %shift4center will be negative if in the unshifted case the left border is bigger than the right border. the vectormatrix is hence not centered on the image. the matrix cannot be shifted more towards the left border because then image2_crop would have a negative index. The only way to center the matrix would be to remove a column of vectors on the right side. but then we weould have less data....
        shift4centerx=0;
    end
    miniy=miniy+shift4centery;
    minix=minix+shift4centerx;
    maxix=maxix+shift4centerx;
    maxiy=maxiy+shift4centery;
    
    image1_roi=padarray(image1_roi,[ceil(interrogationarea/2) ceil(interrogationarea/2)], min(min(image1_roi)));
    image2_roi=padarray(image2_roi,[ceil(interrogationarea/2) ceil(interrogationarea/2)], min(min(image1_roi)));
    mask=padarray(mask,[ceil(interrogationarea/2) ceil(interrogationarea/2)],0);
    if (rem(interrogationarea,2) == 0) %for the subpixel displacement measurement
        SubPixOffset=1;
    else
        SubPixOffset=0.5;
    end
    
    xtable_old=xtable;
    ytable_old=ytable;
    typevector=ones(numelementsy,numelementsx);
    xtable = repmat((minix:step:maxix), numelementsy, 1) + interrogationarea/2;
    ytable = repmat((miniy:step:maxiy)', 1, numelementsx) + interrogationarea/2;
    
    %xtable alt und neu geben koordinaten wo die vektoren herkommen.
    %d.h. u und v auf die gewï¿½nschte grï¿½ï¿½e bringen+interpolieren
    if GUI_avail==1
        set(handles.progress, 'string' , ['Frame progress: ' int2str(j/maxiy*100/passes+((multipass-1)*(100/passes))) '%' sprintf('\n') 'Interpolating velocity field']);drawnow;
        %set(handles.progress, 'string' , 'Interpolating velocity field');drawnow;
    else
        fprintf('.');
    end
    
    utable=interp2(xtable_old,ytable_old,utable,xtable,ytable,'*spline');
    vtable=interp2(xtable_old,ytable_old,vtable,xtable,ytable,'*spline');
    
    utable_1= padarray(utable, [1,1], 'replicate');
    vtable_1= padarray(vtable, [1,1], 'replicate');
    
    %add 1 line around image for border regions... linear extrap
    
    firstlinex=xtable(1,:);
    firstlinex_intp=interp1(1:1:size(firstlinex,2),firstlinex,0:1:size(firstlinex,2)+1,'linear','extrap');
    xtable_1=repmat(firstlinex_intp,size(xtable,1)+2,1);
    
    firstliney=ytable(:,1);
    firstliney_intp=interp1(1:1:size(firstliney,1),firstliney,0:1:size(firstliney,1)+1,'linear','extrap')';
    ytable_1=repmat(firstliney_intp,1,size(ytable,2)+2);
    
    X=xtable_1; %original locations of vectors in whole image
    Y=ytable_1;
    U=utable_1; %interesting portion of u
    V=vtable_1; % "" of v
    
    X1=X(1,1):1:X(1,end)-1;
    Y1=(Y(1,1):1:Y(end,1)-1)';
    X1=repmat(X1,size(Y1, 1),1);
    Y1=repmat(Y1,1,size(X1, 2));
    
    U1 = interp2(X,Y,U,X1,Y1,'*linear');
    V1 = interp2(X,Y,V,X1,Y1,'*linear');
    
    image2_crop_i1 = interp2(1:size(image2_roi,2),(1:size(image2_roi,1))',double(image2_roi),X1+U1,Y1+V1,imdeform); %linear is 3x faster and looks ok...
    
    xb = find(X1(1,:) == xtable_1(1,1));
    yb = find(Y1(:,1) == ytable_1(1,1));
    
    % divide images by small pictures
    % new index for image1_roi
    s0 = (repmat((miniy:step:maxiy)'-1, 1,numelementsx) + repmat(((minix:step:maxix)-1)*size(image1_roi, 1), numelementsy,1))';
    s0 = permute(s0(:), [2 3 1]);
    s1 = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
    ss1 = repmat(s1, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
    % new index for image2_crop_i1
    s0 = (repmat(yb-step+step*(1:numelementsy)'-1, 1,numelementsx) + repmat((xb-step+step*(1:numelementsx)-1)*size(image2_crop_i1, 1), numelementsy,1))';
    s0 = permute(s0(:), [2 3 1]) - s0(1);
    s2 = repmat((1:2*step)',1,2*step) + repmat(((1:2*step)-1)*size(image2_crop_i1, 1),2*step,1);
    ss2 = repmat(s2, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
    
    image1_cut = image1_roi(ss1);
    image2_cut = image2_crop_i1(ss2);
    result_conv = fftshift(fftshift(real(ifft2(conj(fft2(image1_cut)).*fft2(image2_cut))), 1), 2);
    
    
    
    %% repeated correlation
    if repeat == 1
        ms=round(step/4); %multishift parameter so groß wie viertel int window

        %Shift left bot
        image2_crop_i1 = interp2(1:size(image2_roi,2),(1:size(image2_roi,1))',double(image2_roi),X1+U1-ms,Y1+V1+ms,imdeform); %linear is 3x faster and looks ok...
        xb = find(X1(1,:) == xtable_1(1,1));
        yb = find(Y1(:,1) == ytable_1(1,1));
        s0 = (repmat((miniy+ms:step:maxiy+ms)'-1, 1,numelementsx) + repmat(((minix-ms:step:maxix-ms)-1)*size(image1_roi, 1), numelementsy,1))';
        s0 = permute(s0(:), [2 3 1]);
        s1 = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
        ss1 = repmat(s1, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
        s0 = (repmat(yb-step+step*(1:numelementsy)'-1, 1,numelementsx) + repmat((xb-step+step*(1:numelementsx)-1)*size(image2_crop_i1, 1), numelementsy,1))';
        s0 = permute(s0(:), [2 3 1]) - s0(1);
        s2 = repmat((1:2*step)',1,2*step) + repmat(((1:2*step)-1)*size(image2_crop_i1, 1),2*step,1);
        ss2 = repmat(s2, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
        image1_cut = image1_roi(ss1);
        image2_cut = image2_crop_i1(ss2);
        result_convB = fftshift(fftshift(real(ifft2(conj(fft2(image1_cut)).*fft2(image2_cut))), 1), 2);
        
        %figure;imagesc(image1_cut(:,:,100));colormap('gray');figure;imagesc(image2_cut(:,:,100));colormap('gray')
        
        
        %Shift right bot
        image2_crop_i1 = interp2(1:size(image2_roi,2),(1:size(image2_roi,1))',double(image2_roi),X1+U1+ms,Y1+V1+ms,imdeform); %linear is 3x faster and looks ok...
        xb = find(X1(1,:) == xtable_1(1,1));
        yb = find(Y1(:,1) == ytable_1(1,1));
        s0 = (repmat((miniy+ms:step:maxiy+ms)'-1, 1,numelementsx) + repmat(((minix+ms:step:maxix+ms)-1)*size(image1_roi, 1), numelementsy,1))';
        s0 = permute(s0(:), [2 3 1]);
        s1 = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
        ss1 = repmat(s1, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
        s0 = (repmat(yb-step+step*(1:numelementsy)'-1, 1,numelementsx) + repmat((xb-step+step*(1:numelementsx)-1)*size(image2_crop_i1, 1), numelementsy,1))';
        s0 = permute(s0(:), [2 3 1]) - s0(1);
        s2 = repmat((1:2*step)',1,2*step) + repmat(((1:2*step)-1)*size(image2_crop_i1, 1),2*step,1);
        ss2 = repmat(s2, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
        image1_cut = image1_roi(ss1);
        image2_cut = image2_crop_i1(ss2);
        result_convC = fftshift(fftshift(real(ifft2(conj(fft2(image1_cut)).*fft2(image2_cut))), 1), 2);
        
        %Shift left top
        image2_crop_i1 = interp2(1:size(image2_roi,2),(1:size(image2_roi,1))',double(image2_roi),X1+U1-ms,Y1+V1-ms,imdeform); %linear is 3x faster and looks ok...
        xb = find(X1(1,:) == xtable_1(1,1));
        yb = find(Y1(:,1) == ytable_1(1,1));
        s0 = (repmat((miniy-ms:step:maxiy-ms)'-1, 1,numelementsx) + repmat(((minix-ms:step:maxix-ms)-1)*size(image1_roi, 1), numelementsy,1))';
        s0 = permute(s0(:), [2 3 1]);
        s1 = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
        ss1 = repmat(s1, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
        s0 = (repmat(yb-step+step*(1:numelementsy)'-1, 1,numelementsx) + repmat((xb-step+step*(1:numelementsx)-1)*size(image2_crop_i1, 1), numelementsy,1))';
        s0 = permute(s0(:), [2 3 1]) - s0(1);
        s2 = repmat((1:2*step)',1,2*step) + repmat(((1:2*step)-1)*size(image2_crop_i1, 1),2*step,1);
        ss2 = repmat(s2, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
        image1_cut = image1_roi(ss1);
        image2_cut = image2_crop_i1(ss2);
        result_convD = fftshift(fftshift(real(ifft2(conj(fft2(image1_cut)).*fft2(image2_cut))), 1), 2);
        
        %Shift right top
        image2_crop_i1 = interp2(1:size(image2_roi,2),(1:size(image2_roi,1))',double(image2_roi),X1+U1+ms,Y1+V1-ms,imdeform); %linear is 3x faster and looks ok...
        xb = find(X1(1,:) == xtable_1(1,1));
        yb = find(Y1(:,1) == ytable_1(1,1));
        s0 = (repmat((miniy-ms:step:maxiy-ms)'-1, 1,numelementsx) + repmat(((minix+ms:step:maxix+ms)-1)*size(image1_roi, 1), numelementsy,1))';
        s0 = permute(s0(:), [2 3 1]);
        s1 = repmat((1:interrogationarea)',1,interrogationarea) + repmat(((1:interrogationarea)-1)*size(image1_roi, 1),interrogationarea,1);
        ss1 = repmat(s1, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
        s0 = (repmat(yb-step+step*(1:numelementsy)'-1, 1,numelementsx) + repmat((xb-step+step*(1:numelementsx)-1)*size(image2_crop_i1, 1), numelementsy,1))';
        s0 = permute(s0(:), [2 3 1]) - s0(1);
        s2 = repmat((1:2*step)',1,2*step) + repmat(((1:2*step)-1)*size(image2_crop_i1, 1),2*step,1);
        ss2 = repmat(s2, [1, 1, size(s0,3)]) + repmat(s0, [interrogationarea, interrogationarea, 1]);
        image1_cut = image1_roi(ss1);
        image2_cut = image2_crop_i1(ss2);
        result_convE = fftshift(fftshift(real(ifft2(conj(fft2(image1_cut)).*fft2(image2_cut))), 1), 2);
        
        result_conv=result_conv.*result_convB.*result_convC.*result_convD.*result_convE;
        %%}
        
        %figure;imagesc(result_conv(:,:,100))
        %figure;imagesc(result_conv_multiplication(:,:,100))
        

        %{
figure;imagesc(result_conv(:,:,10));
figure;imagesc(result_convB(:,:,10));
figure;imagesc(result_convC(:,:,10));
figure;imagesc(result_convD(:,:,10));
figure;imagesc(result_convE(:,:,10));
        %}
        %%
    end
    
%das zentrum der Matrize (3x3) mit dem mittelwert ersetzen = Keine Autokorrelation
%MARKER
%...aber hier ist ja idealerweise der peak in der Mitte.....
%{
h = fspecial('gaussian', 3, 1.5);
h=h/h(2,2);
h=1-h;
h=repmat(h,1,1,size(result_conv,3));
h=h.*result_conv((interrogationarea/2)+SubPixOffset-1:(interrogationarea/2)+SubPixOffset+1,(interrogationarea/2)+SubPixOffset-1:(interrogationarea/2)+SubPixOffset+1,:);
result_conv((interrogationarea/2)+SubPixOffset-1:(interrogationarea/2)+SubPixOffset+1,(interrogationarea/2)+SubPixOffset-1:(interrogationarea/2)+SubPixOffset+1,:)=h;
%}

if mask_auto == 1
%limit peak search arena....
emptymatrix=zeros(size(result_conv,1),size(result_conv,2),size(result_conv,3));
%emptymatrix=emptymatrix+0.1;
sizeones=4;

%h = fspecial('gaussian', sizeones*2+1,1);
h=fspecial('disk',4);


h=h/max(max(h));
h=repmat(h,1,1,size(result_conv,3));
emptymatrix((interrogationarea/2)+SubPixOffset-sizeones:(interrogationarea/2)+SubPixOffset+sizeones,(interrogationarea/2)+SubPixOffset-sizeones:(interrogationarea/2)+SubPixOffset+sizeones,:)=h;
result_conv = result_conv .* emptymatrix;
%{
figu=figure;
for kuku=1:10:size(result_conv,3)
    imagesc(result_conv(:,:,kuku))
    drawnow;
    pause (0.1)
end
close(figu)
%}
end
    %do fft2
    
    minres = permute(repmat(squeeze(min(min(result_conv))), [1, size(result_conv, 1), size(result_conv, 2)]), [2 3 1]);
    deltares = permute(repmat(squeeze(max(max(result_conv))-min(min(result_conv))), [1, size(result_conv, 1), size(result_conv, 2)]), [2 3 1]);
    result_conv = ((result_conv-minres)./deltares)*255;
    
    %apply mask
    ii = find(mask(ss1(round(interrogationarea/2+1), round(interrogationarea/2+1), :)));
    jj = find(mask((miniy:step:maxiy)+round(interrogationarea/2), (minix:step:maxix)+round(interrogationarea/2)));
    typevector(jj) = 0;
    result_conv(:,:, ii) = 0;
    
    [y, x, z] = ind2sub(size(result_conv), find(result_conv==255));
    [z1, zi] = sort(z);
    % we need only one peak from each couple pictures
    dz1 = [z1(1); diff(z1)];
    i0 = find(dz1~=0);
    x1 = x(zi(i0));
    y1 = y(zi(i0));
    z1 = z(zi(i0));
    
    %new xtable and ytable
    xtable = repmat((minix:step:maxix)+interrogationarea/2, length(miniy:step:maxiy), 1);
    ytable = repmat(((miniy:step:maxiy)+interrogationarea/2)', 1, length(minix:step:maxix));
    
    if subpixfinder==1
        [vector] = SUBPIXGAUSS (result_conv,interrogationarea, x1, y1, z1,SubPixOffset);
    elseif subpixfinder==2
        [vector] = SUBPIX2DGAUSS (result_conv,interrogationarea, x1, y1, z1,SubPixOffset);
    end
    vector = permute(reshape(vector, [size(xtable') 2]), [2 1 3]);
    
    utable = utable+vector(:,:,1);
    vtable = vtable+vector(:,:,2);
    
end

%assignin('base','pass_result',pass_result);
%__________________________________________________________________________


xtable=xtable-ceil(interrogationarea/2);
ytable=ytable-ceil(interrogationarea/2);

xtable=xtable+xroi;
ytable=ytable+yroi;

%profile viewer
%p = profile('info');
%profsave(p,'profile_results')

function [vector] = SUBPIXGAUSS(result_conv, interrogationarea, x, y, z, SubPixOffset)
%was hat peak nr.1 für einen Durchmesser?
%figure;imagesc((1-im2bw(uint8(result_conv(:,:,155)),0.9)).*result_conv(:,:,101))
xi = find(~((x <= (size(result_conv,2)-1)) & (y <= (size(result_conv,1)-1)) & (x >= 2) & (y >= 2)));
x(xi) = [];
y(xi) = [];
z(xi) = [];
xmax = size(result_conv, 2);
vector = NaN(size(result_conv,3), 2);
if(numel(x)~=0)
    ip = sub2ind(size(result_conv), y, x, z);
    %the following 8 lines are copyright (c) 1998, Uri Shavit, Roi Gurka, Alex Liberzon, Technion ï¿½ Israel Institute of Technology
    %http://urapiv.wordpress.com
    f0 = log(result_conv(ip));
    f1 = log(result_conv(ip-1));
    f2 = log(result_conv(ip+1));
    peaky = y + (f1-f2)./(2*f1-4*f0+2*f2);
    f0 = log(result_conv(ip));
    f1 = log(result_conv(ip-xmax));
    f2 = log(result_conv(ip+xmax));
    peakx = x + (f1-f2)./(2*f1-4*f0+2*f2);
    
    SubpixelX=peakx-(interrogationarea/2)-SubPixOffset;
    SubpixelY=peaky-(interrogationarea/2)-SubPixOffset;
    vector(z, :) = [SubpixelX, SubpixelY];
end

function [vector] = SUBPIX2DGAUSS(result_conv, interrogationarea, x, y, z, SubPixOffset)
xi = find(~((x <= (size(result_conv,2)-1)) & (y <= (size(result_conv,1)-1)) & (x >= 2) & (y >= 2)));
x(xi) = [];
y(xi) = [];
z(xi) = [];
xmax = size(result_conv, 2);
vector = NaN(size(result_conv,3), 2);
if(numel(x)~=0)
    c10 = zeros(3,3, length(z));
    c01 = c10;
    c11 = c10;
    c20 = c10;
    c02 = c10;
    ip = sub2ind(size(result_conv), y, x, z);
    
    for i = -1:1
        for j = -1:1
            %following 15 lines based on
            %H. Nobach ï¿½ M. Honkanen (2005)
            %Two-dimensional Gaussian regression for sub-pixel displacement
            %estimation in particle image velocimetry or particle position
            %estimation in particle tracking velocimetry
            %Experiments in Fluids (2005) 38: 511ï¿½515
            c10(j+2,i+2, :) = i*log(result_conv(ip+xmax*i+j));
            c01(j+2,i+2, :) = j*log(result_conv(ip+xmax*i+j));
            c11(j+2,i+2, :) = i*j*log(result_conv(ip+xmax*i+j));
            c20(j+2,i+2, :) = (3*i^2-2)*log(result_conv(ip+xmax*i+j));
            c02(j+2,i+2, :) = (3*j^2-2)*log(result_conv(ip+xmax*i+j));
            %c00(j+2,i+2)=(5-3*i^2-3*j^2)*log(result_conv_norm(maxY+j, maxX+i));
        end
    end
    c10 = (1/6)*sum(sum(c10));
    c01 = (1/6)*sum(sum(c01));
    c11 = (1/4)*sum(sum(c11));
    c20 = (1/6)*sum(sum(c20));
    c02 = (1/6)*sum(sum(c02));
    %c00=(1/9)*sum(sum(c00));
    
    deltax = squeeze((c11.*c01-2*c10.*c02)./(4*c20.*c02-c11.^2));
    deltay = squeeze((c11.*c10-2*c01.*c20)./(4*c20.*c02-c11.^2));
    peakx = x+deltax;
    peaky = y+deltay;
    
    SubpixelX = peakx-(interrogationarea/2)-SubPixOffset;
    SubpixelY = peaky-(interrogationarea/2)-SubPixOffset;
    
    vector(z, :) = [SubpixelX, SubpixelY];
end