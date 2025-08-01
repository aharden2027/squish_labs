%Updated to first release version of PeGS2 by Carmen Lee 29/9/24
%Adapted from Carmen Lee's adaptation of Jonathan Kollmer's PeGS 1.0
%This module compiles the solved force information from each frame into a list to show the contact network
% 
% **I**The input of this module is the standardised MATLAB **particle** structure array. Each particle in the image has the following fields:
% 
% - `id` : assigned ID number of the particle
% - `x`: x coordinate of the particle centre, in *pixels*
% - `y` : y coordinate of the particle centre, in *pixels*
% - `r` : radius of the particle, in *pixels*
% - `rm` : radius of the particle, in *metres*
% - `color` : assigned particle color (for plotting)
% - `fsigma` : photoelastic stress coefficient of the particle
% - `z` : number of contacts on the particle
% - `f` : average force on the particle calculated using the G<sup>2</sup> method
% - `g2` : G<sup>2</sup> value of the particle image
% - `forces` : array of contact force magnitudes 
% - `betas` : array of contact force azimuthal angles
% - `alphas` : array of contact force 'contact angles'. 0 is a purely normal force, $\pm \pi/2$ is a purely tangential force
% - `neighbours` : array containing particle IDs of contacting particles
% - `contactG2s` : array of G<sup>2</sup> values, corresponding to area around each contact force
% - `forceImage` : cropped image of particle from original experimental image
% - `fitError` : error of the least-squares fit
% - `synthImg` : fitted theoretical fringe pattern
% 
% In addition to this, the following user inputs are required:
% 
% 
% - `fmin` : the minimum value of the force to be considered a valid force
% - `fmax` : the maximum value of the force to be considered a valid force
% - `emax` : the maximum value of the fit error to be considered a valid force
% - `skipvalue` : the amount of padding to include in the main data array, will warn if the chosen value is insufficient. Try ~10% of packing size to start
% - `go` : to run adjacency matrix for each frame. If false, it will just try to compile already created adjacency.txt for each file into a large ifle
% 
% 
% 
% **O**
% The output of this module are N individual adjacency lists in the format [frame, id1, id2, tangential, normal] force. As well, 1 txt file listing all adjacencies is saved in the main directory. If verbose is selected, it will show a weighted quiver plot of the force contact network. If the particle has a load bearing contact with the wall, the id will be set to -1.
% 
% ---
% 
% ## Usage
% This module is in the format of the following main blocks
% 
% - `File management and structure initialization` : house keeping
% - `Loading in data and restructuring into adjacency list`
% - `Displaying data` : if verbose
% - `Reloading data into large format`
% - `saving parameters`
% 
% Below the main function is a subfunction used to set defaults

function out = adjacencyMatrix(fileParams, amParams, verbose)


%% FILE MANAGEMENT
if not(isfolder(fullfile(fileParams.topDir,fileParams.adjacencyDir))) %make a new folder with warped images
    mkdir(fullfile(fileParams.topDir,fileParams.adjacencyDir));
end


files = dir(fullfile(fileParams.topDir,fileParams.solvedDir,'*solved.mat')); %which files are we processing ?
nFrames = length(files); %how many files are we processing ?
if nFrames ==0
    error(['wrong spot:',fullfile(fileParams.topDir,fileParams.solvedDir,'*solved.mat'), '--check path']);

else
    disp(['now processing ', num2str(nFrames), 'files into an adjacency matrix'])
end

%% DEFAULT PARAMETERS NEEDED TO RUN THIS SCRIPT ARE SET BELOW IN THE
%SETUPPARAMS FUNCTION

amParams = setupParams(amParams);

%% CREATING INDIVIDUAL adjacency lists

if amParams.go==true
    for cycle = 1:nFrames %loop over these cycles

        clearvars particle;
        clearvars contact;

        % NO PARAMETERS SHOULD BE SET BY HAND BELOW THIS LINE


        pres = load(fullfile(files(cycle).folder, files(cycle).name)); %read output from diskSolve
        particle = pres.particle;
        NN = length(particle);
        IDN = max([particle.id]);
        ids = [particle.id];

        %DATA EVALUATION AND ANALYSIS STARTS HERE


        N = NaN(IDN+1); %empty normal force weighted adjacency matrix (one extra column/row for edge force)
        T = NaN(IDN+1); %empty tangential force weighted adjacency matrix

        if verbose %if we want to plot the data we need another structure
            clear contactpos
            contactpos(1:NN) = struct('x',[], 'y',[], 'cx', [], 'cy', [], 'forces', []);
        end

        for n = 1:NN %for each particle
            err = particle(n).fitError; %get fit error


            if ~isempty(particle(n).neighbours) % particle is in contact
                contacts = particle(n).neighbours; %get IDs of all contacting particles

                forces = particle(n).forces; %get the force associated with each contact
                alphas = particle(n).alphas; %get the alpha angle (direction of force) associated with each contact

                for m=1:length(forces) %for each contact

                    if(abs(forces(m)) > amParams.fmin && err < amParams.emax && abs(forces(m)) < amParams.fmax) %is this a valid contact ?

                        %put information about the first particle involved in this
                        %contact in the corresponding particle structure vector

                        targetid = contacts(m);
                        tind1m = ids == targetid;
                        tind1 = find(tind1m); %dealing with particle ids that don't correspond to index (if tracked)


                        %build some adjacency matrices
                        if contacts(m) > 0
                            N(particle(n).id,particle(tind1).id) = real(forces(m))*cos(alphas(m)); %write the corrsponding normal force as a weight into an adjacency matrix
                            T(particle(n).id,particle(tind1).id) = real(forces(m))*sin(alphas(m)); %write the corrsponding tangential force as a weight into an adjacency matrix
                        else
                            N(particle(n).id, IDN+1) = real(forces(m))*cos(alphas(m)); %write the corrsponding normal force as a weight into an adjacency matrix
                            T(particle(n).id,IDN+1) = real(forces(m))*sin(alphas(m)); %for edges
                        end
                        if verbose %save data for plotting

                            contactpos(n).x(m) = particle(n).x;
                            contactpos(n).y(m) = particle(n).y;
                            contactpos(n).cx(m) = particle(n).r*cos(particle(n).betas(m));
                            contactpos(n).cy(m) = particle(n).r*sin(particle(n).betas(m));
                            contactpos(n).forces(m) = abs(forces(m));
                        end
                    end
                end
            end

        end
        if isfield(fileParams, 'frameIdInd')
            frameid = str2double(files(cycle).name(fileParams.frameIdInd:fileParams.frameIdInd+3));
        else
            frameid = cycle;
        end
        d = ~isnan(T); %remove empty data
        [row , col] = find(d==1);
        ind=sub2ind(size(T),row,col);
        col(col ==IDN+1) = -1; %assign edge neighbour id as -1


        list = [ones(length(row),1).*frameid,row , col , T(ind) , N(ind)];
        savename = strrep(files(cycle).name, 'solved.mat', 'Adjacency.txt');
        writematrix(list, fullfile(fileParams.topDir, fileParams.adjacencyDir,savename) ); %save an adjacency list for the given frame 
        %format [frameid, id1, id2, tangential force, normal force]



        if verbose
            figure(1)
            %read and display the original image used as input
            camImageFileName = strrep(files(cycle).name, '_solved.mat', '.png');
            img = imread(fullfile(fileParams.topDir, fileParams.imgDir,camImageFileName)); 
            imshow(img); hold on;

            
            %
            f = [contactpos.forces]; %set linescale
            norm = max(max(f));
            shift = min(min(f));

            %(not my best coding, can be improved -CL)
            for m= 1:length(contactpos)
                plot(contactpos(m).x, contactpos(m).y, 'or'); %plot the centers of all particles associated with a contact
                for z =1:size(contactpos(m).x,2)
                    linewidths = 10*(contactpos(m).forces(z)-shift+0.001)/norm;
                    quiver(contactpos(m).x(z),contactpos(m).y(z),contactpos(m).cx(z),contactpos(m).cy(z),0,'LineWidth',linewidths, Color='b') %             %plot arrows from the centers of all particles associated with a contact to
            %             %the contact point
                end
            end

            drawnow;
        end


    end
end
%% Compile all of the adjacency lists into a master list
AdjFiles = dir(fullfile(fileParams.topDir, fileParams.adjacencyDir, '*_Adjacency.txt'));
nFrames = length(AdjFiles);
testData = load(fullfile(AdjFiles(nFrames).folder, AdjFiles(nFrames).name));

skipamount = length(testData)+amParams.skipvalue;
Adj_list = nan(nFrames*skipamount, 5);

for frame = 1:nFrames


    adjData = load([AdjFiles(frame).folder, '/', AdjFiles(frame).name]);

    if size(adjData, 1) > skipamount
        error(['up the skipamount by', num2str(length(adjData)-skipamount)])
    end
    Adj_list((frame-1)*skipamount+1:(frame-1)*skipamount +length(adjData),:) = adjData;
end
Adj_list(any(isnan(Adj_list),2),:)=[];

%frame number, particle 1, particle id 2, tangential force, normal force
writematrix(Adj_list, fullfile(fileParams.topDir,'Adjacency_list.txt'));


%%save parameters

fields = fieldnames(amParams);
for i = 1:length(fields)
    fileParams.(fields{i}) = amParams.(fields{i});
end


fileParams.time = datetime("now");
fields = fieldnames(fileParams);
C=struct2cell(fileParams);
amParams = [fields C];

writecell(amParams,fullfile(fileParams.topDir, fileParams.adjacencyDir,'adjacencyMatrix_params.txt'),'Delimiter','tab')



if verbose
    disp('done with adjacencyMatrix()');
end

out = true;
end





function params = setupParams(params)

if isfield(params,'go') == 0
    params.go = true;
end
if isfield(params,'fmin') == 0
    params.fmin = 0.000001;%minimum force (in Newton) to consider a contact a valid contact
end


if isfield(params,'fmax') == 0
    params.fmax = 1000; %maximum force (in Newton) to consider a contact a valid contact
end

if isfield(params,'emax') == 0
    params.emax = 2800; %maximum fit error/residual to consider a contact a valid contact
end

if isfield(params,'skipvalue') == 0
    params.skipvalue = 20; %I chose this as a result of my system size, could and should be altered based on your specific system and variability in finding particles

end

end
