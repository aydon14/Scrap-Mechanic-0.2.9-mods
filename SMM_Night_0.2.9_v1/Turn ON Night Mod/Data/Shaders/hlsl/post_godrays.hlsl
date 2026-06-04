#include "base_transform.h"
#include "base_texture.h"
#include "base_rendering.h"
#include "base_math.h"
#include "base_shadow.h"

cbuffer CS_RTSIZE : register( b10 )
{
	float4 vRtSize;
};

struct VS_INPUT
{
	float4 vLocalPosition 	: POSITION;
	float2 vUv			 	: TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 vPosition  		: SV_Position;
};

Texture2D		tDepth		: register( t0 );
Texture2DArray	taCascades	: register( t1 );


// -------------------------------------------------------------------
// vertex functions
// -------------------------------------------------------------------

VS_OUTPUT mainVS( VS_INPUT input )
{
	VS_OUTPUT output;
	output.vPosition = float4( input.vLocalPosition.xy * 2.0 - 1.0, 1.0, 1.0 );

    return output;
};

// -------------------------------------------------------------------
// pixel functions
// -------------------------------------------------------------------

static const float Rand[64] = {
	0.5812435625, 0.1755130939, 0.5773812415, 0.6302625489, 0.9157151699, 0.6239344890, 0.0823797197, 0.3656869840,
	0.6209343808, 0.4557871314, 0.4128129541, 0.1954525812, 0.1495418730, 0.9772899382, 0.9218936764, 0.3550820233,
	0.4289238558, 0.3415204384, 0.1350318573, 0.3735138010, 0.9814555209, 0.7868003421, 0.5017340025, 0.7624520194,
	0.4700040189, 0.2337477379, 0.9263954918, 0.4123050599, 0.0384631960, 0.4496070423, 0.9166926634, 0.7958192893,
	0.2987334961, 0.6878718520, 0.9199990897, 0.5948356397, 0.2455536279, 0.5445638793, 0.7095571767, 0.8421780159,
	0.3623420723, 0.5029978406, 0.1651945257, 0.7180143521, 0.9563527190, 0.0239255282, 0.7702463894, 0.3938634013,
	0.0902333989, 0.7381059086, 0.3863340875, 0.1188350744, 0.7461711495, 0.4534665570, 0.9295868438, 0.8102192289,
	0.0335657100, 0.5737184475, 0.3370439849, 0.1583394389, 0.4385470276, 0.0599520180, 0.8724608424, 0.8187828420
};

static const uint Samples = 64;
static const float MaxDepth = 48.0;

float4 mainPS( VS_OUTPUT input ) : SV_Target0
{
	float2 uvAligned = input.vPosition.xy * vRtSize.zw;

	float fDepth = PointSampleCC( tDepth, uvAligned ).r;

	float fRnd = Rand[int( fmod( input.vPosition.x, 8 ) + fmod( input.vPosition.y, 8 ) * 8 )];

	float3 vWorldSpaceCamPos = getCameraPosition();
	float3 vViewSpaceRayFar = depthAndUvToViewPosition( fDepth, uvAligned, projectionToView );
	float vViewSpaceRayLength = length( vViewSpaceRayFar );
	float3 vViewSpaceRayDir = vViewSpaceRayFar / vViewSpaceRayLength;

	float3 vWorldSpaceRayFar = mul( viewToWorld, float4( vViewSpaceRayDir * min( vViewSpaceRayLength, MaxDepth ), 1.0 ) ).xyz;

	float fIntensity = pow( max( dot( -vSunDirectionView.xyz, normalize( vViewSpaceRayFar ) ), 0.0 ), 1.5 ) + 0.2;

	float light = 0.0;

	static const float fStep = 1.0 / float( Samples + 1 );

	for( uint i = 0; i < Samples; ++i ) {

		float l = 1.0;

		float3 vWorldSpacePosition = lerp( vWorldSpaceCamPos, vWorldSpaceRayFar, ( i + fRnd ) * fStep );

		uint iCascadeIndex = selectCascadeFromWorldPosition( vWorldSpacePosition );
		if( iCascadeIndex < 4 )
		{
			float4 vClipSpace = calculateClipSpacePos( iCascadeIndex, vWorldSpacePosition );

			float fTargetDepth = LinearSampleArrayCC( taCascades, vClipSpace.xy, iCascadeIndex ).r;

			float fThisDepth = vClipSpace.z;

			if( vClipSpace.x > 1.0 || vClipSpace.x < 0.0f ) fTargetDepth = 1.0;
			if( vClipSpace.y > 1.0 || vClipSpace.y < 0.0f ) fTargetDepth = 1.0;

			l = fTargetDepth < fThisDepth ? 1.0 : 0.0;
		}

		light += (l * fIntensity) / float( Samples );
	}

	return float4( float3( 0.425, 0.275, 0.135 ) * light * 0.6, 1.0 ) * 0.0;
}
