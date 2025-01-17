classdef fastrack_3d_agent < RTD_agent_2D
% Class: fastrack_agent < RTD_agent_2D < agent
%
% T
    
    properties
        integrator_type = 'ode45' ; 
        integrator_time_discretization = 0.01 ; % for ode4
        % state limits
        max_speed = 2 ; % m/s (NOTE this is higher than in the specs, since
                        % the planner should not command speeds above its
                        % own limit, but the robot is not limited by the
                        % planning algorithm)
        
        % state indices
        speed_index = 4 ;
                        
        % input limits (NOTE these are higher than in the paper as well,
        % and are based on guesses of what the TurtleBot does in YouTube
        % videos, where it can spin and accelerate really fast)
        max_yaw_rate = 2.0 ; % rad/s     
        max_accel = 2.0 ; % m/s^2   
        LLCP
    end
    
    methods
        %% constructor
        function A = fastrack_3d_agent(varargin)
            % set up default superclass values
            default_footprint = 0.35/2 ;
            n_states = 4 ;
            n_inputs = 2 ;
            stopping_time = 1 ;
            sensor_radius = 3 ;
            LLC =  fastrack_3d_LLC;
            LLCP = turtlebot_PD_LLC ;
            
            % create agent
            A@RTD_agent_2D('footprint',default_footprint,...
                'n_states',n_states,'n_inputs',n_inputs,...
                'stopping_time',stopping_time,'sensor_radius',sensor_radius,...
                'LLC',LLC,'LLCP',LLCP,'name','FasTrack Agent',varargin{:}) ;
        end
        
        %% emergency stop
        % note, this ignores any previous trajectory the agent may have
        % been tracking; we have to define this different from the default
        % for the TurtleBot because it takes in acceleration as a control
        % input, as opposed to doing feedback about desired speed
        function stop(A,t_stop)
            if nargin < 2
                t_stop = A.stopping_time ;
            end
            
            % get the current speed
            v = A.state(A.speed_index,end) ;

            % check how long it will take to come to a stop and make the
            % stopping time vector
            t_req_to_stop = v/A.max_accel ;            
            T_input = [0, max(t_req_to_stop,t_stop)] ;
            
            % generate the input
            U_input = zeros(2,2) ;
            
            % generate desired trajectory
            z0 = A.state(:,end) ;
            h = A.state(3,end) ;
            z1 = z0 + [0.001*cos(h) ; sin(h) ; 0 ; 0] ;
            Z_input = [z0 z1] ;
            
            % call move method to perform stop
            A.move(t_stop,T_input,U_input,Z_input) ;
        end
        
        %% dynamics
        function zd = dynamics(A,t,z,T,U,Z)
            % handle no desired trajectory input
            if nargin < 6
                Z = [] ;
            end
            
            % extract the states
            h = z(A.heading_index) ;
            v = z(A.speed_index) ;
            
            % get nominal control inputs
           [u_s, normalizer] = A.LLC.get_control_inputs(A,t,z,T,U,Z);
            u_p = A.LLCP.get_control_inputs(A,t,z,T,U,Z);
            %u = (normalizer > 0.8) * u_s + (normalizer< 0.8)*(u_s * normalizer + u_p* (1-normalizer));
            u = u_s;
            u(isnan(u)) = 0 ; % safety check
            w_des = u(1) ;
            a_des = u(2) ;
            
            % saturate the inputs.  This is not actually necessary for
            % fastrack, inherently implemented. SS
            w = bound_values(w_des,A.max_yaw_rate) ;
            a = bound_values(a_des,A.max_accel) ;
            
            % calculate the derivatives
            xd = v*cos(h) ;
            yd = v*sin(h) ;
            hd = w ;
            vd = a ;
            
            % return state derivative
            zd = [xd ; yd ; hd ; vd] ;
        end
        function [tout,zout] = integrator(A,fun,tspan,z0)
            switch A.integrator_type
                case 'ode45'
                   opts = odeset('RelTol',1e-2,'AbsTol',1e-2);

                    [tout,zout] = ode45(@(t,z) fun(t,z),tspan,z0(:),opts) ;
                case 'ode113'
                    [tout,zout] = ode113(@(t,z) fun(t,z),tspan,z0(:)) ;
                case {'ode4','RK4'}
                    dt = A.integrator_time_discretization ;
                    tout = tspan(1):dt:tspan(end) ;
                    if tout(end) ~= tspan(end)
                        tout = [tout, tspan(end)] ;
                    end
                    zout = ode4(@(t,z) fun(t,z),tout,z0(:)) ;
                otherwise
                    error('Please set A.integrator_type to either ode45 or ode4')
            end
            tout = tout(:)' ;
            zout = zout' ;
        end
    end
end