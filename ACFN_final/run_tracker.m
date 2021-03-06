
%
%  Attentional Correlation Filter Network for Adaptive Visual Tracking
%
%  Jongwon Choi, 2017
%  https://sites.google.com/site/jwchoivision/  
% 
%  MATLAB code for correlation filter network
%  When you use this code for your research, please refer the below references.
%  You can't use this code for any commercial purpose without author's
%  agreement.
%  If you have any question or comment, please contact to
%  jwchoi.pil@gmail.com.
%  
%  Inputs --
%  seq_path : path to image sequence files
%  init_bbox : [center_x, center_y, w, h] bounding box at the first frame
%  PORT : socket communication port number (with attentional network)
% 
%  Outputs --
%  bbox : tracking results one row [center_x, center_y, w, h] for each frame
%  fps : average speed
% 
%  Examples:
%  >> run_tracker('data/Freeman1/', [264,80,23,28], 50006);
%
%  Reference:
%  [1] J. Choi, et al., "Attentional Correlation Filter Network for Adaptive Visual Tracking", CVPR2017
%  [2] J. Choi, et al., "Visual Tracking Using Attention-Modulated Disintegration and Integration", CVPR2016

function [bbox, fps] = run_tracker(seq_path, init_bbox, PORT)

% Libaray load
addpath('strong');
addpath('tools');
addpath('KCFs');
addpath(genpath('PiotrDollarToolbox'));
if count(py.sys.path,'./socket_py') == 0
    insert(py.sys.path,int32(0),'./socket_py');
end

% socket connection
CONN = py.tcp_server.connect(py.int(PORT));

% Parameter setting
padding = 1.5;
lambda = 1e-4;
output_sigma_factor = 0.05;
interp_factor = 0.02;
% gaussian kernel
kernel.sigma = 0.5;
% polynomial kernel
kernel.poly_a = 1;
kernel.poly_b = 9;
% hog feature
features.hog_orientations = 9;
cell_size = 4;
%visualization
show_visualization = 1;

% find image files
img_files = dir([seq_path '*.png']);
if(isempty(img_files))
    img_files = dir([seq_path '*.jpg']);
end
img_files = sort({img_files.name});

% tracking start
[positions, time] = tracker(seq_path, img_files, init_bbox([2,1]), init_bbox([4,3]), ...
            padding, kernel, lambda, output_sigma_factor, interp_factor, ...
            cell_size, features, show_visualization, CONN);
     
% socket disconnect
temp = [2, 2];
py.tcp_server.send(CONN, single(temp));
py.tcp_server.disconnect(CONN);
      
% final results
bbox = [(positions(:,[1,2]) + positions(:,[3,4])) / 2 ,...
    (positions(:,[3,4]) - positions(:,[1,2]))];
fps = numel(img_files) / time;
       
